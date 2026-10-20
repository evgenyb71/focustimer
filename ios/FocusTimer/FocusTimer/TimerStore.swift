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

        /// Fields that do not belong to the phase are removed. A running phase without a
        /// deadline falls back to idle; a paused phase without positive remaining time is
        /// treated as expired, so Focus waits for Break confirmation and Break returns to idle.
        var repaired: TimerState {
            switch phase {
            case .idle, .waitingForAConfirm:
                return TimerState(phase: phase)
            case .runningA, .runningB:
                if paused {
                    guard let remainingSeconds, remainingSeconds > 0 else {
                        return TimerState(phase: phase == .runningA ? .waitingForAConfirm : .idle)
                    }
                    return TimerState(phase: phase, endTimestamp: nil, paused: true, remainingSeconds: remainingSeconds)
                }
                guard let endTimestamp else { return TimerState() }
                return TimerState(phase: phase, endTimestamp: endTimestamp, paused: false, remainingSeconds: nil)
            }
        }
    }

    static let repairNotice = "Saved timer data was corrected."

    static let shared = TimerStore()

    @Published var configuration: Configuration
    @Published private(set) var state: TimerState
    @Published private(set) var displayedSeconds: Int?
    @Published private(set) var noticeMessage: String?

    private let configurationKey = "config"
    private let stateKey = "state"
    private let clock: any Clock
    private let store: any KeyValueStore
    private let notifications: any NotificationScheduling
    private var ticker: Timer?

    init(
        clock: any Clock = SystemClock(),
        store: any KeyValueStore = UserDefaults.standard,
        notifications: any NotificationScheduling = SystemNotificationScheduler()
    ) {
        self.clock = clock
        self.store = store
        self.notifications = notifications
        let savedConfiguration = Self.decode(Configuration.self, key: configurationKey, from: store) ?? Configuration()
        let savedState = Self.decode(TimerState.self, key: stateKey, from: store) ?? TimerState()
        configuration = savedConfiguration.normalized
        state = savedState.repaired
        if configuration != savedConfiguration {
            persistConfiguration()
        }
        if state != savedState {
            persistState()
            if state.phase != savedState.phase {
                notifications.cancelAllPendingCompletions()
            }
        }
        if configuration != savedConfiguration || state != savedState {
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
        startPhase(.runningA, durationSeconds: configuration.durationASeconds)
    }

    func startBreak() {
        guard state.phase == .waitingForAConfirm else { return }
        startPhase(.runningB, durationSeconds: configuration.durationBSeconds)
    }

    func startBreakFromNotification() {
        reconcileWithCurrentTime()
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
            notifications.scheduleCompletion(for: state.phase, at: deadline, now: now)
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

    private func startPhase(_ phase: Phase, durationSeconds: Int) {
        let now = clock.now
        let deadline = now.addingTimeInterval(TimeInterval(durationSeconds))
        state = TimerState(phase: phase, endTimestamp: deadline, paused: false, remainingSeconds: nil)
        noticeMessage = nil
        persistState()
        updateDisplayedTime()
        notifications.scheduleCompletion(for: phase, at: deadline, now: now)
    }

    private func handlePhaseCompletion() {
        switch state.phase {
        case .runningA:
            state = TimerState(phase: .waitingForAConfirm)
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

    private func persistConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            store.setData(data, forKey: configurationKey)
        }
    }

    private func persistState() {
        if let data = try? JSONEncoder().encode(state) {
            store.setData(data, forKey: stateKey)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, from store: any KeyValueStore) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
