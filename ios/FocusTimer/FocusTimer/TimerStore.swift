import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class TimerStore: ObservableObject {
    enum Phase: String, Codable {
        case idle
        case runningA
        case waitingForAConfirm
        case runningB
        /// Break has ended; the cycle is finished until the user starts a new Focus or presses Done.
        case completed
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

        /// The full length of a timed phase, or nil for idle and waiting.
        func duration(of phase: Phase) -> Int? {
            switch phase {
            case .runningA: durationASeconds
            case .runningB: durationBSeconds
            case .idle, .waitingForAConfirm, .completed: nil
            }
        }

        /// How long a timed phase runs when a minute lasts `secondsPerMinute` seconds. With 60 it equals
        /// `duration(of:)`; a shorter minute exists only in Debug builds, for manual checks.
        func runLength(of phase: Phase, secondsPerMinute: Int) -> Int? {
            duration(of: phase).map { $0 * secondsPerMinute / 60 }
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
        /// treated as expired, so Focus waits for Break confirmation and Break is completed.
        /// Every phase except idle gets a new cycle ID if it has none.
        var repaired: TimerState {
            let cycleID = cycleID ?? UUID()
            switch phase {
            case .idle:
                return TimerState()
            case .waitingForAConfirm, .completed:
                return TimerState(phase: phase, cycleID: cycleID)
            case .runningA, .runningB:
                if paused {
                    guard let remainingSeconds, remainingSeconds > 0 else {
                        return TimerState(phase: phase == .runningA ? .waitingForAConfirm : .completed, cycleID: cycleID)
                    }
                    return TimerState(phase: phase, endTimestamp: nil, paused: true, remainingSeconds: remainingSeconds, cycleID: cycleID)
                }
                guard let endTimestamp else { return TimerState() }
                return TimerState(phase: phase, endTimestamp: endTimestamp, paused: false, remainingSeconds: nil, cycleID: cycleID)
            }
        }

        /// A paused remaining time longer than the phase's full length is shortened to that length.
        func clampingPausedTime(to configuration: Configuration, secondsPerMinute: Int = 60) -> TimerState {
            guard paused, let remainingSeconds,
                  let duration = configuration.runLength(of: phase, secondsPerMinute: secondsPerMinute),
                  remainingSeconds > duration else { return self }
            var state = self
            state.remainingSeconds = duration
            return state
        }
    }

    /// How the status card presents the end of a phase.
    enum EndState: Equatable {
        case focusComplete
        case breakComplete
    }

    static let repairNotice = "Saved timer data was corrected."
    static let schedulingFailureNotice = "The end-of-phase alert couldn't be scheduled. Keep the app open to see when it ends."
    static let alertsDeniedHint = "Alerts are off, so you won't be told when a phase ends. Turn them on in Settings > Notifications > FocusTimer."

    /// Version of the saved `config` and `state` format. Records saved before versioning are version 0.
    nonisolated static let currentSchemaVersion = 3

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
        // 2 → 3: adds the `completed` phase. No record changes; the new version makes builds that predate it
        // treat such data as a newer version instead of failing to decode the state.
        { _ in },
    ]

    static let shared = TimerStore(secondsPerMinute: launchSecondsPerMinute())

    /// Seconds in a minute for the app's store. Debug builds read an optional setting so that manual checks
    /// finish quickly (`scripts/debug-minute.sh`); a missing or invalid value means 60. Release builds always
    /// use 60 and contain neither the setting nor its key.
    private static func launchSecondsPerMinute() -> Int {
        #if DEBUG
        UserDefaults.standard.integer(forKey: "debugSecondsPerMinute")
        #else
        60
        #endif
    }

    @Published var configuration: Configuration
    @Published private(set) var state: TimerState
    @Published private(set) var displayedSeconds: Int?
    @Published private(set) var noticeMessage: String?
    /// True while the user has turned alerts off. Not saved; read at launch and on each activation.
    @Published private(set) var alertsDenied = false
    /// The latest permission read, kept so tests can wait for it.
    private(set) var alertPermissionCheck: Task<Void, Never>?

    private static let configurationKey = "config"
    private static let stateKey = "state"
    private static let schemaVersionKey = "schemaVersion"
    private let clock: any Clock
    private let store: any KeyValueStore
    private let notifications: any NotificationScheduling
    private var ticker: Timer?
    /// True when launch ignored records of a newer or unreadable schema version.
    private var versionNeedsWrite = false
    /// How many seconds each configured minute runs for: 60, or 1–59 in a Debug build set up for quick checks.
    let secondsPerMinute: Int

    init(
        clock: any Clock = SystemClock(),
        store: any KeyValueStore = UserDefaults.standard,
        notifications: any NotificationScheduling = SystemNotificationScheduler(),
        secondsPerMinute: Int = 60
    ) {
        self.clock = clock
        self.store = store
        self.notifications = notifications
        self.secondsPerMinute = (1...60).contains(secondsPerMinute) ? secondsPerMinute : 60
        if Self.migrateSavedRecords(in: store, versionKey: Self.schemaVersionKey) {
            let configurationUnreadable = Self.isUnreadable(Configuration.self, key: Self.configurationKey, in: store)
            let stateUnreadable = Self.isUnreadable(TimerState.self, key: Self.stateKey, in: store)
            let savedConfiguration = Self.decode(Configuration.self, key: Self.configurationKey, from: store) ?? Configuration()
            let savedState = Self.decode(TimerState.self, key: Self.stateKey, from: store) ?? TimerState()
            let normalizedConfiguration = savedConfiguration.normalized
            configuration = normalizedConfiguration
            state = savedState.repaired.clampingPausedTime(to: normalizedConfiguration, secondsPerMinute: self.secondsPerMinute)
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
            // An end screen the user already had when the app closed does not come back. Going by the saved
            // phase, before reconciling, lets a phase that expired while closed still show its end screen once.
            if savedState.phase == .waitingForAConfirm || savedState.phase == .completed {
                state = TimerState()
                persistState()
                notifications.cancelAllPendingCompletions()
                notifications.removeAllDeliveredCompletions()
            }
        } else {
            // Records from a newer or unreadable version are not interpreted and are left untouched at
            // launch. The first save replaces them and writes the current version.
            configuration = Configuration()
            state = TimerState()
            versionNeedsWrite = true
            noticeMessage = Self.repairNotice
        }
        // Reconcile before anything reads the countdown: it caps or completes a saved deadline that is out
        // of range, and it updates the display itself.
        reconcileWithCurrentTime()
        removeObsoleteDeliveredCompletions()
        startTicker()
        checkAlertPermission()
    }

    var canEditDurations: Bool { state.phase == .idle || state.phase == .completed }
    var canStart: Bool { state.phase == .idle || state.phase == .waitingForAConfirm || state.phase == .completed }
    var canPause: Bool { state.phase == .runningA || state.phase == .runningB }
    var canFinish: Bool { state.phase == .completed }
    /// A finished cycle ends with Done, so Cancel is not offered in completed.
    var canCancel: Bool { state.phase != .completed }

    var endState: EndState? {
        switch state.phase {
        case .waitingForAConfirm: .focusComplete
        case .completed: .breakComplete
        case .idle, .runningA, .runningB: nil
        }
    }

    /// The headline shown instead of the time at the end of a phase.
    var endHeadline: String? {
        switch endState {
        case .focusComplete: "Focus complete"
        case .breakComplete: "Cycle complete"
        case nil: nil
        }
    }

    var statusTitle: String {
        switch state.phase {
        case .idle: "Ready"
        case .completed: "Cycle complete"
        case .runningA: state.paused ? "Focus paused" : "Focus Timer running"
        case .waitingForAConfirm: "Focus Timer complete"
        case .runningB: state.paused ? "Break paused" : "Break Timer running"
        }
    }

    var statusMessage: String {
        if let noticeMessage { return noticeMessage }
        return switch state.phase {
        case .idle: "Set durations and press Start."
        case .completed: "Restart for another Focus, or press Done to finish."
        case .runningA: state.paused ? "Resume to continue Focus." : "Break Timer will wait for confirmation."
        case .waitingForAConfirm: "Take a break when you're ready."
        case .runningB: state.paused ? "Resume to continue Break." : "Waiting for completion."
        }
    }

    var primaryButtonTitle: String {
        switch endState {
        case .focusComplete: "Start Break"
        case .breakComplete: "Restart"
        case nil: "Start"
        }
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
        guard state.phase == .idle || state.phase == .completed else { return }

        configuration = configuration.normalized
        persistConfiguration()
        // A new cycle makes every earlier alert obsolete. Idle does not prove that no request is pending:
        // launch can ignore an unsupported saved version while a Break request is still scheduled.
        notifications.cancelAllPendingCompletions()
        notifications.removeAllDeliveredCompletions()
        startPhase(.runningA, durationSeconds: runLength(of: .runningA), cycleID: UUID())
    }

    func startBreak() {
        guard state.phase == .waitingForAConfirm else { return }
        startPhase(.runningB, durationSeconds: runLength(of: .runningB), cycleID: state.cycleID ?? UUID())
        notifications.removeDeliveredCompletion(for: .runningA)
    }

    /// Starts Break from a Focus notification's action, only when the action belongs to the current
    /// cycle. An action from an earlier cycle, without an ID, or repeated after Break started does nothing.
    func startBreakFromNotification(cycleID: UUID?) {
        // Checked before reconciling, as in `doneFromNotification`.
        guard let cycleID, cycleID == state.cycleID else { return }
        reconcileWithCurrentTime()
        startBreak()
    }

    /// Ends a finished cycle from the Break notification's Done, only when the action belongs to the
    /// current cycle. An action from an earlier cycle, without an ID, after a launch reset, or repeated after
    /// Done does nothing.
    func doneFromNotification(cycleID: UUID?) {
        // Check the cycle before reconciling, so a rejected action cannot complete or reschedule a newer
        // cycle. Reconciling keeps the cycle ID, so a matching action still finds a Break that has ended.
        guard let cycleID, cycleID == state.cycleID else { return }
        reconcileWithCurrentTime()
        done()
    }

    /// Starts a new Focus from the Break notification's Restart, only when the action belongs to the current
    /// cycle and that cycle is complete. An action from an earlier cycle, without an ID, after a launch reset,
    /// or repeated after Restart does nothing.
    func restartFromNotification(cycleID: UUID?) {
        // Checked before reconciling, as in `doneFromNotification`.
        guard let cycleID, cycleID == state.cycleID else { return }
        reconcileWithCurrentTime()
        // `startFocus()` also starts from idle, so the completed check keeps Restart to a finished cycle.
        guard state.phase == .completed else { return }
        startFocus()
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
            scheduleCompletion(for: state.phase, at: deadline, now: now, cycleID: state.cycleID)
        } else {
            // At or after expiry the phase completes instead of pausing.
            reconcileWithCurrentTime()
            guard canPause, !state.paused, let deadline = state.endTimestamp else { return }
            let remaining = max(1, wholeSecondsUntil(deadline))
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
        notifications.removeAllDeliveredCompletions()
        persistState()
        updateDisplayedTime()
    }

    /// Ends a finished cycle: saves the durations and returns to idle. In any other phase, including
    /// after an earlier Done, it does nothing.
    func done() {
        guard canFinish else { return }

        configuration = configuration.normalized
        persistConfiguration()
        state = TimerState()
        noticeMessage = nil
        // Like Cancel: a request can outlive the state (see `startFocus()`).
        notifications.cancelAllPendingCompletions()
        notifications.removeAllDeliveredCompletions()
        persistState()
        updateDisplayedTime()
    }

    /// Runs when the app becomes active: catches up with the current time, then removes delivered
    /// alerts that no longer match the timer.
    func activate() {
        reconcileWithCurrentTime()
        removeObsoleteDeliveredCompletions()
        checkAlertPermission()
    }

    /// The hint shown while alerts are off, or nil.
    var alertsHint: String? { alertsDenied ? Self.alertsDeniedHint : nil }

    /// Reads the permission to alert and updates the denied hint. Timer flow never waits for it.
    func checkAlertPermission() {
        alertPermissionCheck = Task {
            let status = await notifications.authorizationStatus()
            alertsDenied = NotificationScheduler.isDenied(status)
        }
    }

    func reconcileWithCurrentTime() {
        guard !state.paused,
              state.phase == .runningA || state.phase == .runningB,
              let deadline = state.endTimestamp else {
            updateDisplayedTime()
            return
        }
        let now = clock.now
        if deadline <= now {
            handlePhaseCompletion()
            return
        }
        // After a backward clock jump the deadline can be further away than the phase is long;
        // it is moved to now + the full length, so the timer never shows more than its length.
        if let duration = configuration.normalized.runLength(of: state.phase, secondsPerMinute: secondsPerMinute),
           deadline.timeIntervalSince(now) > TimeInterval(duration) {
            let capped = now.addingTimeInterval(TimeInterval(duration))
            state.endTimestamp = capped
            persistState()
            scheduleCompletion(for: state.phase, at: capped, now: now, cycleID: state.cycleID)
        }
        updateDisplayedTime()
    }

    /// The current configuration's run length for a timed phase; 0 for any other phase.
    private func runLength(of phase: Phase) -> Int {
        configuration.runLength(of: phase, secondsPerMinute: secondsPerMinute) ?? 0
    }

    private func startPhase(_ phase: Phase, durationSeconds: Int, cycleID: UUID) {
        let now = clock.now
        let deadline = now.addingTimeInterval(TimeInterval(durationSeconds))
        state = TimerState(phase: phase, endTimestamp: deadline, paused: false, remainingSeconds: nil, cycleID: cycleID)
        noticeMessage = nil
        persistState()
        updateDisplayedTime()
        scheduleCompletion(for: phase, at: deadline, now: now, cycleID: cycleID)
    }

    /// Schedules the completion alert. A failure shows the notice only while the same run is still current,
    /// so a late failure cannot show it for a later phase, cycle, or deadline. The timer goes on either way.
    private func scheduleCompletion(for phase: Phase, at deadline: Date, now: Date, cycleID: UUID?) {
        notifications.scheduleCompletion(for: phase, at: deadline, now: now, cycleID: cycleID) { [weak self] in
            guard let self,
                  !self.alertsDenied,
                  self.state.phase == phase,
                  self.state.cycleID == cycleID,
                  !self.state.paused,
                  self.state.endTimestamp == deadline else { return }
            self.noticeMessage = Self.schedulingFailureNotice
        }
    }

    private func handlePhaseCompletion() {
        switch state.phase {
        case .runningA:
            state = TimerState(phase: .waitingForAConfirm, cycleID: state.cycleID)
        case .runningB:
            state = TimerState(phase: .completed, cycleID: state.cycleID)
            // The delivered Break alert is the current alert while completed; leaving completed removes it.
            notifications.cancelPendingCompletion(for: .runningB)
        case .idle, .waitingForAConfirm, .completed:
            return
        }
        persistState()
        updateDisplayedTime()
    }

    /// Keeps the delivered Focus alert only while Break waits for confirmation, and the Break alert only while
    /// Break runs or the cycle is completed. Uses the phase alone, so it also clears alerts from before cycle IDs
    /// or a recovery reset.
    private func removeObsoleteDeliveredCompletions() {
        if state.phase != .waitingForAConfirm {
            notifications.removeDeliveredCompletion(for: .runningA)
        }
        if state.phase != .runningB && state.phase != .completed {
            notifications.removeDeliveredCompletion(for: .runningB)
        }
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

    /// Whole seconds until the deadline, rounded up. Bounded before the `Int` conversion, which would trap
    /// on an extreme saved date.
    private func wholeSecondsUntil(_ deadline: Date) -> Int {
        let seconds = ceil(deadline.timeIntervalSince(clock.now))
        return Int(min(max(seconds, Double(Int32.min)), Double(Int32.max)))
    }

    private func updateDisplayedTime() {
        if state.paused, let remaining = state.remainingSeconds {
            displayedSeconds = max(0, remaining)
        } else if let deadline = state.endTimestamp {
            displayedSeconds = max(0, wholeSecondsUntil(deadline))
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
