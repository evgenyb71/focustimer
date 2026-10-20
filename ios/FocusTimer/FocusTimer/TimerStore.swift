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
        var durationASeconds: Int = 60
        var durationBSeconds: Int = 60
    }

    struct TimerState: Codable, Equatable {
        var phase: Phase = .idle
        var endTimestamp: Date?
        var paused = false
        var remainingSeconds: Int?
    }

    static let shared = TimerStore()

    @Published var configuration: Configuration
    @Published private(set) var state: TimerState
    @Published private(set) var displayedSeconds: Int?
    @Published private(set) var errorMessage: String?

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
        configuration = Self.decode(Configuration.self, key: configurationKey, from: store) ?? Configuration()
        state = Self.decode(TimerState.self, key: stateKey, from: store) ?? TimerState()
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
        if let errorMessage { return errorMessage }
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
        errorMessage = nil
        if state.phase == .waitingForAConfirm {
            startBreak()
            return
        }
        startFocus()
    }

    func startFocus() {
        guard state.phase == .idle else { return }
        guard configuration.durationASeconds >= 1, configuration.durationBSeconds >= 1 else {
            errorMessage = "Durations must be at least one second."
            return
        }

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
        errorMessage = nil

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
        errorMessage = nil
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
        errorMessage = nil
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
