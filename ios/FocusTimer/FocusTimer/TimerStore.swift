import Foundation
import SwiftUI

@MainActor
final class TimerStore: ObservableObject {
    enum Phase: String, Codable {
        case idle
        case runningA
        case waitingForAConfirm
        case runningB
    }

    struct Configuration: Codable, Equatable {
        static let focusRange = 60...(240 * 60)
        static let breakRange = 60...(120 * 60)

        var durationASeconds: Int = 60
        var durationBSeconds: Int = 60

        /// Each duration rounded to the nearest whole minute, then clamped to its range.
        var normalized: Configuration {
            Configuration(
                durationASeconds: Self.normalize(durationASeconds, to: Self.focusRange),
                durationBSeconds: Self.normalize(durationBSeconds, to: Self.breakRange)
            )
        }

        private static func normalize(_ seconds: Int, to range: ClosedRange<Int>) -> Int {
            let wholeMinutes = (Double(seconds) / 60).rounded() * 60
            return Int(min(max(wholeMinutes, Double(range.lowerBound)), Double(range.upperBound)))
        }
    }

    struct TimerState: Codable, Equatable {
        var phase: Phase = .idle
        var endTimestamp: Date?
        var paused = false
        var remainingSeconds: Int?
        /// Identifies one Focus → Break cycle. Idle has none; every other phase has one.
        var cycleID: UUID?

        /// Fields that do not belong to the phase are removed. A running phase without a
        /// deadline falls back to idle; a paused phase without positive remaining time is
        /// treated as expired, so Focus waits for Break confirmation and Break returns to idle.
        /// An active phase without a cycle ID gets a new one.
        var repaired: TimerState {
            let cycleID = cycleID ?? UUID()
            switch phase {
            case .idle:
                return TimerState()
            case .waitingForAConfirm:
                return TimerState(phase: phase, cycleID: cycleID)
            case .runningA, .runningB:
                if paused {
                    guard let remainingSeconds, remainingSeconds > 0 else {
                        return phase == .runningA ? TimerState(phase: .waitingForAConfirm, cycleID: cycleID) : TimerState()
                    }
                    return TimerState(phase: phase, endTimestamp: nil, paused: true, remainingSeconds: remainingSeconds, cycleID: cycleID)
                }
                guard let endTimestamp else { return TimerState() }
                return TimerState(phase: phase, endTimestamp: endTimestamp, paused: false, remainingSeconds: nil, cycleID: cycleID)
            }
        }
    }

    static let repairNotice = "Saved timer data was corrected."

    /// Version of the saved `config` and `state` format. Records saved before versioning are version 0.
    nonisolated static let currentSchemaVersion = 2

    /// Steps that update saved records by one version, in order: the step at index n migrates version n to n + 1.
    private static let migrations: [@MainActor (any KeyValueStore) -> Void] = [
        // 0 → 1: unversioned records already have the version 1 format; only the version is added.
        { _ in },
        // 1 → 2: an active cycle gets a cycle ID and keeps its timer. Alerts scheduled before the
        // upgrade carry no ID, so their action is ignored. An unreadable state is left for recovery.
        { store in
            guard let data = store.data(forKey: TimerStore.stateKey),
                  var state = try? JSONDecoder().decode(TimerState.self, from: data),
                  state.phase != .idle, state.cycleID == nil else { return }
            state.cycleID = UUID()
            if let data = try? JSONEncoder().encode(state) {
                store.setData(data, forKey: TimerStore.stateKey)
            }
        },
    ]

    static let shared = TimerStore()

    @Published var configuration: Configuration
    @Published private(set) var state: TimerState
    @Published private(set) var displayedSeconds: Int?
    @Published private(set) var noticeMessage: String?

    private static let configurationKey = "config"
    private static let stateKey = "state"
    private static let schemaVersionKey = "schemaVersion"
    private let clock: any Clock
    private let store: any KeyValueStore
    private let notifications: any NotificationScheduling
    private var ticker: Timer?
    /// True when launch ignored records of a newer or unreadable schema version.
    private var versionNeedsWrite = false

    init(
        clock: any Clock = SystemClock(),
        store: any KeyValueStore = UserDefaults.standard,
        notifications: any NotificationScheduling = SystemNotificationScheduler()
    ) {
        self.clock = clock
        self.store = store
        self.notifications = notifications
        if Self.migrateSavedRecords(in: store, versionKey: Self.schemaVersionKey) {
            let configurationUnreadable = Self.isUnreadable(Configuration.self, key: Self.configurationKey, in: store)
            let stateUnreadable = Self.isUnreadable(TimerState.self, key: Self.stateKey, in: store)
            let savedConfiguration = Self.decode(Configuration.self, key: Self.configurationKey, from: store) ?? Configuration()
            let savedState = Self.decode(TimerState.self, key: Self.stateKey, from: store) ?? TimerState()
            configuration = savedConfiguration.normalized
            state = savedState.repaired
            if configuration != savedConfiguration || configurationUnreadable {
                persistConfiguration()
            }
            if state != savedState || stateUnreadable {
                persistState()
                // An unreadable state may have been a running phase whose alert is still pending.
                if state.phase != savedState.phase || stateUnreadable {
                    notifications.cancelAllPendingCompletions()
                }
            }
            if configuration != savedConfiguration || state != savedState || configurationUnreadable || stateUnreadable {
                noticeMessage = Self.repairNotice
            }
        } else {
            // Records from a newer or unreadable version are not interpreted and are left untouched at
            // launch. The first save replaces them and writes the current version.
            configuration = Configuration()
            state = TimerState()
            versionNeedsWrite = true
            noticeMessage = Self.repairNotice
        }
        updateDisplayedTime()
        reconcileWithCurrentTime()
        startTicker()
    }

    var canEditDurations: Bool { state.phase == .idle }
    var canStart: Bool { state.phase == .idle || state.phase == .waitingForAConfirm }
    var canPause: Bool { state.phase == .runningA || state.phase == .runningB }

    var statusTitle: String {
        switch state.phase {
        case .idle: "Ready"
        case .runningA: state.paused ? "Focus paused" : "Focus Timer running"
        case .waitingForAConfirm: "Focus Timer complete"
        case .runningB: state.paused ? "Break paused" : "Break Timer running"
        }
    }

    var statusMessage: String {
        if let noticeMessage { return noticeMessage }
        return switch state.phase {
        case .idle: "Set durations and press Start."
        case .runningA: state.paused ? "Resume to continue Focus." : "Break Timer will wait for confirmation."
        case .waitingForAConfirm: "Press Start Break to begin."
        case .runningB: state.paused ? "Resume to continue Break." : "Waiting for completion."
        }
    }

    var primaryButtonTitle: String {
        state.phase == .waitingForAConfirm ? "Start Break" : "Start"
    }

    func startOrConfirmBreak() {
        noticeMessage = nil
        if state.phase == .waitingForAConfirm {
            startBreak()
            return
        }
        startFocus()
    }

    func startFocus() {
        guard state.phase == .idle else { return }

        configuration = configuration.normalized
        persistConfiguration()
        startPhase(.runningA, durationSeconds: configuration.durationASeconds, cycleID: UUID())
    }

    func startBreak() {
        guard state.phase == .waitingForAConfirm else { return }
        startPhase(.runningB, durationSeconds: configuration.durationBSeconds, cycleID: state.cycleID ?? UUID())
    }

    /// Starts Break from a Focus notification's action, only when the action belongs to the current
    /// cycle. An action from an earlier cycle, without an ID, or repeated after Break started does nothing.
    func startBreakFromNotification(cycleID: UUID?) {
        reconcileWithCurrentTime()
        guard let cycleID, cycleID == state.cycleID else { return }
        startBreak()
    }

    func pauseOrResume() {
        guard canPause else { return }
        noticeMessage = nil

        if state.paused {
            guard let remaining = state.remainingSeconds, remaining > 0 else { return }
            let now = clock.now
            let deadline = now.addingTimeInterval(TimeInterval(remaining))
            state.endTimestamp = deadline
            state.remainingSeconds = nil
            state.paused = false
            persistState()
            notifications.scheduleCompletion(for: state.phase, at: deadline, now: now, cycleID: state.cycleID)
        } else {
            guard let deadline = state.endTimestamp else { return }
            let remaining = max(1, Int(ceil(deadline.timeIntervalSince(clock.now))))
            state.endTimestamp = nil
            state.remainingSeconds = remaining
            state.paused = true
            notifications.cancelPendingCompletion(for: state.phase)
            persistState()
        }
        updateDisplayedTime()
    }

    func cancel() {
        state = TimerState()
        noticeMessage = nil
        notifications.cancelAllPendingCompletions()
        persistState()
        updateDisplayedTime()
    }

    func reconcileWithCurrentTime() {
        guard !state.paused,
              state.phase == .runningA || state.phase == .runningB,
              let deadline = state.endTimestamp,
              deadline <= clock.now else {
            updateDisplayedTime()
            return
        }
        handlePhaseCompletion()
    }

    private func startPhase(_ phase: Phase, durationSeconds: Int, cycleID: UUID) {
        let now = clock.now
        let deadline = now.addingTimeInterval(TimeInterval(durationSeconds))
        state = TimerState(phase: phase, endTimestamp: deadline, paused: false, remainingSeconds: nil, cycleID: cycleID)
        noticeMessage = nil
        persistState()
        updateDisplayedTime()
        notifications.scheduleCompletion(for: phase, at: deadline, now: now, cycleID: cycleID)
    }

    private func handlePhaseCompletion() {
        switch state.phase {
        case .runningA:
            state = TimerState(phase: .waitingForAConfirm, cycleID: state.cycleID)
        case .runningB:
            state = TimerState()
        case .idle, .waitingForAConfirm:
            return
        }
        persistState()
        updateDisplayedTime()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    private func tick() {
        reconcileWithCurrentTime()
        updateDisplayedTime()
    }

    private func updateDisplayedTime() {
        if state.paused, let remaining = state.remainingSeconds {
            displayedSeconds = max(0, remaining)
        } else if let deadline = state.endTimestamp {
            displayedSeconds = max(0, Int(ceil(deadline.timeIntervalSince(clock.now))))
        } else if state.phase == .waitingForAConfirm {
            displayedSeconds = 0
        } else {
            displayedSeconds = nil
        }
    }

    /// On the first save after launch ignored an unsupported version, replaces both records and writes
    /// the current version, so the next launch reads what this app saved.
    private func claimUnsupportedVersion() {
        guard versionNeedsWrite else { return }
        versionNeedsWrite = false
        if let data = try? JSONEncoder().encode(configuration) {
            store.setData(data, forKey: Self.configurationKey)
        }
        if let data = try? JSONEncoder().encode(state) {
            store.setData(data, forKey: Self.stateKey)
        }
        if let data = try? JSONEncoder().encode(Self.currentSchemaVersion) {
            store.setData(data, forKey: Self.schemaVersionKey)
        }
    }

    private func persistConfiguration() {
        claimUnsupportedVersion()
        if let data = try? JSONEncoder().encode(configuration) {
            store.setData(data, forKey: Self.configurationKey)
        }
    }

    private func persistState() {
        claimUnsupportedVersion()
        if let data = try? JSONEncoder().encode(state) {
            store.setData(data, forKey: Self.stateKey)
        }
    }

    /// Brings saved records up to the current schema version and saves the new version.
    /// Returns false, writing nothing, when the saved version is newer or unreadable.
    private static func migrateSavedRecords(in store: any KeyValueStore, versionKey: String) -> Bool {
        let savedVersion: Int?
        if let data = store.data(forKey: versionKey) {
            savedVersion = try? JSONDecoder().decode(Int.self, from: data)
        } else {
            savedVersion = 0
        }
        guard let savedVersion, (0...currentSchemaVersion).contains(savedVersion) else { return false }
        guard savedVersion < currentSchemaVersion else { return true }

        assert(migrations.count == currentSchemaVersion)
        for migrate in migrations[savedVersion...] {
            migrate(store)
        }
        if let data = try? JSONEncoder().encode(currentSchemaVersion) {
            store.setData(data, forKey: versionKey)
        }
        return true
    }

    /// A record that is saved but cannot be decoded. A missing record is not unreadable.
    private static func isUnreadable<T: Decodable>(_ type: T.Type, key: String, in store: any KeyValueStore) -> Bool {
        store.data(forKey: key) != nil && decode(type, key: key, from: store) == nil
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, from store: any KeyValueStore) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
