import Foundation
@testable import FocusTimer

@MainActor
final class FakeClock: Clock {
    var now: Date

    init(now: Date = Date(timeIntervalSinceReferenceDate: 1_000_000)) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

@MainActor
final class InMemoryStore: KeyValueStore {
    private(set) var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? {
        values[key]
    }

    func setData(_ data: Data, forKey key: String) {
        values[key] = data
    }
}

@MainActor
final class RecordingNotificationScheduler: NotificationScheduling {
    enum Call: Equatable {
        case schedule(phase: TimerStore.Phase, deadline: Date, now: Date)
        case cancel(phase: TimerStore.Phase)
        case cancelAll
    }

    private(set) var calls: [Call] = []

    func scheduleCompletion(for phase: TimerStore.Phase, at deadline: Date, now: Date) {
        calls.append(.schedule(phase: phase, deadline: deadline, now: now))
    }

    func cancelPendingCompletion(for phase: TimerStore.Phase) {
        calls.append(.cancel(phase: phase))
    }

    func cancelAllPendingCompletions() {
        calls.append(.cancelAll)
    }
}
