import Foundation
import UserNotifications
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
    private(set) var writtenKeys: [String] = []

    func data(forKey key: String) -> Data? {
        values[key]
    }

    func setData(_ data: Data, forKey key: String) {
        values[key] = data
        writtenKeys.append(key)
    }
}

@MainActor
final class RecordingNotificationScheduler: NotificationScheduling {
    enum Call: Equatable {
        case schedule(phase: TimerStore.Phase, deadline: Date, now: Date)
        case cancel(phase: TimerStore.Phase)
        case cancelAll
        case removeDelivered(phase: TimerStore.Phase)
        case removeAllDelivered
    }

    private(set) var calls: [Call] = []
    /// Calls that schedule or cancel pending requests, without removals of delivered alerts.
    var pendingCalls: [Call] {
        calls.filter {
            switch $0 {
            case .removeDelivered, .removeAllDelivered: false
            default: true
            }
        }
    }
    /// Removals of delivered alerts only.
    var deliveredCalls: [Call] {
        calls.filter {
            switch $0 {
            case .removeDelivered, .removeAllDelivered: true
            default: false
            }
        }
    }
    /// The cycle ID passed with each `schedule` call, in order.
    private(set) var scheduledCycleIDs: [UUID?] = []

    /// Phases with a pending completion request, modelled like Notification Center: scheduling replaces
    /// the request for the same phase, and cancelling removes it.
    private(set) var pendingPhases: Set<TimerStore.Phase> = []

    /// What `authorizationStatus()` returns.
    var status: UNAuthorizationStatus = .authorized
    /// The failure handler passed with each `schedule` call, in order. Calling one simulates iOS rejecting
    /// that request, at whatever moment the test chooses.
    private(set) var failureHandlers: [@MainActor () -> Void] = []

    func scheduleCompletion(
        for phase: TimerStore.Phase,
        at deadline: Date,
        now: Date,
        cycleID: UUID?,
        onFailure: @escaping @MainActor () -> Void
    ) {
        calls.append(.schedule(phase: phase, deadline: deadline, now: now))
        scheduledCycleIDs.append(cycleID)
        failureHandlers.append(onFailure)
        pendingPhases.insert(phase)
    }

    /// When true, each status read waits in `heldStatusReads` until the test resumes it.
    var holdsStatusReads = false
    private(set) var heldStatusReads: [CheckedContinuation<UNAuthorizationStatus, Never>] = []

    func authorizationStatus() async -> UNAuthorizationStatus {
        guard holdsStatusReads else { return status }
        return await withCheckedContinuation { heldStatusReads.append($0) }
    }

    func cancelPendingCompletion(for phase: TimerStore.Phase) {
        calls.append(.cancel(phase: phase))
        pendingPhases.remove(phase)
    }

    func cancelAllPendingCompletions() {
        calls.append(.cancelAll)
        pendingPhases.removeAll()
    }

    func removeDeliveredCompletion(for phase: TimerStore.Phase) {
        calls.append(.removeDelivered(phase: phase))
    }

    func removeAllDeliveredCompletions() {
        calls.append(.removeAllDelivered)
    }
}

extension TimerStore.TimerState {
    /// The state without its cycle ID, for tests about timing rather than cycle identity.
    var ignoringCycle: TimerStore.TimerState {
        var state = self
        state.cycleID = nil
        return state
    }
}

// MARK: Shared test arguments

enum TimedPhase: CaseIterable, Sendable {
    case focus
    case breakTime
}

enum UnversionedState: CaseIterable, Sendable {
    case idle
    case runningFocus
    case runningBreak
    case pausedFocus
    case pausedBreak
    case waitingForBreak
}
