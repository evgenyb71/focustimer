import Foundation
import Testing
@testable import FocusTimer

enum NoticeClearingAction: CaseIterable, Sendable {
    case start
    case startBreak
    case pause
    case resume
    case cancel
}

@MainActor
struct TimerStoreInvariantTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func seed(configuration: TimerStore.Configuration? = nil, state: TimerStore.TimerState? = nil) {
        if let configuration, let data = try? JSONEncoder().encode(configuration) {
            store.setData(data, forKey: "config")
        }
        if let state, let data = try? JSONEncoder().encode(state) {
            store.setData(data, forKey: "state")
        }
    }

    func load() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
    }

    func savedState() -> TimerStore.TimerState? {
        store.values["state"].flatMap { try? JSONDecoder().decode(TimerStore.TimerState.self, from: $0) }
    }

    func savedConfiguration() -> TimerStore.Configuration? {
        store.values["config"].flatMap { try? JSONDecoder().decode(TimerStore.Configuration.self, from: $0) }
    }

    func phase(_ phase: TimedPhase) -> TimerStore.Phase {
        phase == .focus ? .runningA : .runningB
    }

    // MARK: Duration bounds and whole minutes

    @Test(arguments: [
        (0, 60), (-120, 60), (20, 60), (30, 60), (89, 60), (90, 120), (150, 180),
        (120, 120), (14_400, 14_400), (14_430, 14_400), (999 * 60, 14_400),
        (Int.max, 14_400), (Int.min, 60),
    ])
    func focusDurationIsRoundedAndClampedOnLoad(_ saved: Int, _ expected: Int) {
        seed(configuration: TimerStore.Configuration(durationASeconds: saved, durationBSeconds: 60))

        let timer = load()

        let repaired = TimerStore.Configuration(durationASeconds: expected, durationBSeconds: 60)
        #expect(timer.configuration == repaired)
        #expect(savedConfiguration() == repaired)
        #expect((timer.statusMessage == TimerStore.repairNotice) == (saved != expected))
    }

    @Test(arguments: [
        (0, 60), (20, 60), (90, 120), (7_200, 7_200), (7_260, 7_200), (240 * 60, 7_200),
    ])
    func breakDurationIsRoundedAndClampedOnLoad(_ saved: Int, _ expected: Int) {
        seed(configuration: TimerStore.Configuration(durationASeconds: 60, durationBSeconds: saved))

        let timer = load()

        let repaired = TimerStore.Configuration(durationASeconds: 60, durationBSeconds: expected)
        #expect(timer.configuration == repaired)
        #expect(savedConfiguration() == repaired)
        #expect((timer.statusMessage == TimerStore.repairNotice) == (saved != expected))
    }

    @Test func repairingOneDurationKeepsTheOther() {
        seed(configuration: TimerStore.Configuration(durationASeconds: 90 * 60, durationBSeconds: 0))

        let timer = load()

        #expect(timer.configuration == TimerStore.Configuration(durationASeconds: 90 * 60, durationBSeconds: 60))
    }

    @Test func startFocusClampsInMemoryConfiguration() {
        let timer = load()
        let start = clock.now
        timer.configuration = TimerStore.Configuration(durationASeconds: 30, durationBSeconds: 999 * 60)

        timer.startFocus()

        let clamped = TimerStore.Configuration(durationASeconds: 60, durationBSeconds: 7_200)
        #expect(timer.configuration == clamped)
        #expect(savedConfiguration() == clamped)
        #expect(timer.state.endTimestamp == start.addingTimeInterval(60))
    }

    // MARK: Missing required fields

    @Test(arguments: TimedPhase.allCases)
    func runningWithoutDeadlineFallsBackToIdle(_ timed: TimedPhase) {
        let configuration = TimerStore.Configuration(durationASeconds: 120, durationBSeconds: 180)
        seed(
            configuration: configuration,
            state: TimerStore.TimerState(phase: phase(timed), endTimestamp: nil, paused: false, remainingSeconds: 30)
        )

        let timer = load()

        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.configuration == configuration)
        #expect(savedState() == TimerStore.TimerState())
        #expect(notifications.pendingCalls == [.cancelAll])
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    @Test(arguments: TimedPhase.allCases, [nil, 0, -5] as [Int?])
    func pausedWithoutRemainingTimeIsTreatedAsExpired(_ timed: TimedPhase, _ remaining: Int?) {
        seed(state: TimerStore.TimerState(
            phase: phase(timed),
            endTimestamp: clock.now.addingTimeInterval(30),
            paused: true,
            remainingSeconds: remaining
        ))

        let timer = load()

        let expected = timed == .focus
            ? TimerStore.TimerState(phase: .waitingForAConfirm)
            : TimerStore.TimerState(phase: .completed)
        #expect(timer.state.ignoringCycle == expected)
        #expect(savedState()?.ignoringCycle == expected)
        #expect(notifications.pendingCalls == [.cancelAll])
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    // MARK: Stray fields

    @Test func strayTimingFieldsAreRemovedWhenIdle() {
        seed(state: TimerStore.TimerState(
            phase: .idle,
            endTimestamp: clock.now.addingTimeInterval(30),
            paused: true,
            remainingSeconds: 10
        ))

        let timer = load()

        #expect(timer.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
        #expect(notifications.pendingCalls.isEmpty)
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    @Test func aWaitingStateWithStrayTimingFieldsResetsWithNotice() {
        seed(state: TimerStore.TimerState(
            phase: .waitingForAConfirm,
            endTimestamp: clock.now.addingTimeInterval(30),
            paused: true,
            remainingSeconds: 10
        ))

        let timer = load()

        #expect(timer.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    @Test(arguments: TimedPhase.allCases)
    func strayRemainingTimeIsRemovedWhileRunning(_ timed: TimedPhase) {
        let deadline = clock.now.addingTimeInterval(30)
        seed(state: TimerStore.TimerState(phase: phase(timed), endTimestamp: deadline, paused: false, remainingSeconds: 10))

        let timer = load()

        let expected = TimerStore.TimerState(phase: phase(timed), endTimestamp: deadline, paused: false, remainingSeconds: nil)
        #expect(timer.state.ignoringCycle == expected)
        #expect(savedState()?.ignoringCycle == expected)
        #expect(notifications.pendingCalls.isEmpty)
        #expect(timer.displayedSeconds == 30)
    }

    @Test(arguments: TimedPhase.allCases)
    func strayDeadlineIsRemovedWhilePaused(_ timed: TimedPhase) {
        seed(state: TimerStore.TimerState(
            phase: phase(timed),
            endTimestamp: clock.now.addingTimeInterval(-100),
            paused: true,
            remainingSeconds: 40
        ))

        let timer = load()

        let expected = TimerStore.TimerState(phase: phase(timed), endTimestamp: nil, paused: true, remainingSeconds: 40)
        #expect(timer.state.ignoringCycle == expected)
        #expect(savedState()?.ignoringCycle == expected)
        #expect(timer.displayedSeconds == 40)
    }

    @Test func repairedRunningFocusWithPassedDeadlineStillReconciles() {
        seed(state: TimerStore.TimerState(
            phase: .runningA,
            endTimestamp: clock.now.addingTimeInterval(-1),
            paused: false,
            remainingSeconds: 10
        ))

        let timer = load()

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(phase: .waitingForAConfirm))
        #expect(savedState()?.ignoringCycle == TimerStore.TimerState(phase: .waitingForAConfirm))
    }

    // MARK: Valid records and the notice

    @Test func validRecordsLoadUnchangedWithoutNotice() {
        let configuration = TimerStore.Configuration(durationASeconds: 25 * 60, durationBSeconds: 5 * 60)
        let state = TimerStore.TimerState(phase: .runningB, endTimestamp: nil, paused: true, remainingSeconds: 42, cycleID: UUID())
        seed(configuration: configuration, state: state)
        if let version = try? JSONEncoder().encode(TimerStore.currentSchemaVersion) {
            store.setData(version, forKey: "schemaVersion")
        }
        let savedValues = store.values

        let timer = load()

        #expect(timer.configuration == configuration)
        #expect(timer.state == state)
        #expect(store.values == savedValues)
        #expect(notifications.pendingCalls.isEmpty)
        #expect(timer.statusMessage != TimerStore.repairNotice)
    }

    @Test(arguments: NoticeClearingAction.allCases)
    func noticeClearsOnNextAction(_ action: NoticeClearingAction) {
        let deadline = clock.now.addingTimeInterval(30)
        switch action {
        case .start, .cancel:
            seed(configuration: TimerStore.Configuration(durationASeconds: 0, durationBSeconds: 60))
        case .startBreak:
            seed(state: TimerStore.TimerState(phase: .waitingForAConfirm, endTimestamp: deadline, paused: false, remainingSeconds: nil))
        case .pause:
            seed(state: TimerStore.TimerState(phase: .runningA, endTimestamp: deadline, paused: false, remainingSeconds: 10))
        case .resume:
            seed(state: TimerStore.TimerState(phase: .runningA, endTimestamp: deadline, paused: true, remainingSeconds: 10))
        }
        let timer = load()
        #expect(timer.statusMessage == TimerStore.repairNotice)

        switch action {
        case .start, .startBreak:
            timer.startOrConfirmBreak()
        case .pause, .resume:
            timer.pauseOrResume()
        case .cancel:
            timer.cancel()
        }

        #expect(timer.statusMessage != TimerStore.repairNotice)
    }
}
