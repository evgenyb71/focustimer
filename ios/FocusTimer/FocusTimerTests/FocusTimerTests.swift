import Foundation
import Testing
@testable import FocusTimer

@MainActor
struct TimerStoreNotificationTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
    }

    @Test func startFocusSchedulesFocusCompletion() {
        let timer = makeTimer()
        let start = clock.now

        timer.startFocus()

        #expect(timer.state.phase == .runningA)
        #expect(notifications.pendingCalls == [
            .schedule(phase: .runningA, deadline: start.addingTimeInterval(60), now: start)
        ])
    }

    @Test func pauseCancelsFocusCompletion() {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 10)

        timer.pauseOrResume()

        #expect(timer.state.paused)
        #expect(timer.state.remainingSeconds == 50)
        #expect(notifications.pendingCalls.last == .cancel(phase: .runningA))
    }

    @Test func resumeSchedulesFromRemainingTime() {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 10)
        timer.pauseOrResume()
        clock.advance(by: 100)
        let resumedAt = clock.now

        timer.pauseOrResume()

        #expect(!timer.state.paused)
        #expect(notifications.pendingCalls.last == .schedule(
            phase: .runningA,
            deadline: resumedAt.addingTimeInterval(50),
            now: resumedAt
        ))
    }

    @Test func cancelCancelsAllCompletions() {
        let timer = makeTimer()
        timer.startFocus()

        timer.cancel()

        #expect(timer.state.phase == .idle)
        #expect(notifications.pendingCalls.last == .cancelAll)
    }

    @Test func breakIsScheduledOnlyAfterConfirmation() {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)

        timer.reconcileWithCurrentTime()

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(notifications.pendingCalls.count == 1)

        let confirmedAt = clock.now
        timer.startBreak()

        #expect(timer.state.phase == .runningB)
        #expect(notifications.pendingCalls.last == .schedule(
            phase: .runningB,
            deadline: confirmedAt.addingTimeInterval(60),
            now: confirmedAt
        ))
    }

    @Test func persistsThroughInjectedStore() {
        let timer = makeTimer()

        timer.startFocus()

        #expect(store.values["config"] != nil)
        #expect(store.values["state"] != nil)
    }
}

enum TimedPhase: CaseIterable, Sendable {
    case focus
    case breakTime
}

enum CancelStart: CaseIterable, Sendable {
    case runningFocus
    case pausedFocus
    case waitingForBreak
    case runningBreak
    case pausedBreak
}

@MainActor
struct TimerStoreTransitionTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    let focusSeconds = 120
    let breakSeconds = 60

    func makeTimer() -> TimerStore {
        let timer = TimerStore(clock: clock, store: store, notifications: notifications)
        timer.configuration = TimerStore.Configuration(
            durationASeconds: focusSeconds,
            durationBSeconds: breakSeconds
        )
        return timer
    }

    func makeWaitingForBreak() -> TimerStore {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: TimeInterval(focusSeconds))
        timer.reconcileWithCurrentTime()
        return timer
    }

    func makeRunning(_ phase: TimedPhase) -> TimerStore {
        switch phase {
        case .focus:
            let timer = makeTimer()
            timer.startFocus()
            return timer
        case .breakTime:
            let timer = makeWaitingForBreak()
            timer.startBreak()
            return timer
        }
    }

    func storePhase(_ phase: TimedPhase) -> TimerStore.Phase {
        phase == .focus ? .runningA : .runningB
    }

    func duration(_ phase: TimedPhase) -> Int {
        phase == .focus ? focusSeconds : breakSeconds
    }

    func savedState() -> TimerStore.TimerState? {
        store.values["state"].flatMap { try? JSONDecoder().decode(TimerStore.TimerState.self, from: $0) }
    }

    func savedConfiguration() -> TimerStore.Configuration? {
        store.values["config"].flatMap { try? JSONDecoder().decode(TimerStore.Configuration.self, from: $0) }
    }

    // MARK: Focus, Break, and explicit confirmation

    @Test func startFocusRunsFocusAndPersistsConfiguration() {
        let timer = makeTimer()
        let start = clock.now

        timer.startFocus()

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(
            phase: .runningA,
            endTimestamp: start.addingTimeInterval(TimeInterval(focusSeconds)),
            paused: false,
            remainingSeconds: nil
        ))
        #expect(savedState() == timer.state)
        #expect(savedConfiguration() == timer.configuration)
    }

    @Test func primaryActionStartsFocusFromIdleAndConfirmsBreakFromWaiting() {
        let timer = makeTimer()

        timer.startOrConfirmBreak()
        #expect(timer.state.phase == .runningA)

        clock.advance(by: TimeInterval(focusSeconds))
        timer.reconcileWithCurrentTime()
        timer.startOrConfirmBreak()
        #expect(timer.state.phase == .runningB)
    }

    @Test func startFocusIsIgnoredWhileRunning() {
        let timer = makeRunning(.focus)
        let runningState = timer.state

        timer.startFocus()

        #expect(timer.state == runningState)
        #expect(notifications.pendingCalls.count == 1)
    }

    @Test func startFocusIsIgnoredWhileWaiting() {
        let timer = makeWaitingForBreak()
        let callCount = notifications.pendingCalls.count

        timer.startFocus()

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(phase: .waitingForAConfirm))
        #expect(notifications.pendingCalls.count == callCount)
    }

    @Test func startBreakIsIgnoredWhenIdle() {
        let timer = makeTimer()

        timer.startBreak()

        #expect(timer.state == TimerStore.TimerState())
        #expect(notifications.pendingCalls.isEmpty)
    }

    @Test func startBreakIsIgnoredWhileFocusRuns() {
        let timer = makeRunning(.focus)
        let runningState = timer.state

        timer.startBreak()

        #expect(timer.state == runningState)
        #expect(notifications.pendingCalls.count == 1)
    }

    @Test func focusExpiryWaitsForConfirmation() {
        let timer = makeRunning(.focus)
        clock.advance(by: TimeInterval(focusSeconds - 1))
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .runningA)

        clock.advance(by: 1)
        timer.reconcileWithCurrentTime()

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(phase: .waitingForAConfirm))
        #expect(savedState() == timer.state)
        #expect(notifications.pendingCalls.count == 1)
    }

    @Test func breakNeverStartsByItself() {
        let timer = makeWaitingForBreak()

        for _ in 0..<3 {
            clock.advance(by: 10_000)
            timer.reconcileWithCurrentTime()
        }

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(notifications.pendingCalls.count == 1)
    }

    @Test func breakExpiryReturnsToIdleKeepingConfiguration() {
        let timer = makeRunning(.breakTime)

        clock.advance(by: TimeInterval(breakSeconds))
        timer.reconcileWithCurrentTime()

        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.configuration == TimerStore.Configuration(
            durationASeconds: focusSeconds,
            durationBSeconds: breakSeconds
        ))
        #expect(savedState() == TimerStore.TimerState())
    }

    // MARK: Pause and resume

    @Test(arguments: TimedPhase.allCases)
    func pauseFreezesRemainingTime(_ phase: TimedPhase) {
        let timer = makeRunning(phase)
        clock.advance(by: 10)

        timer.pauseOrResume()

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(
            phase: storePhase(phase),
            endTimestamp: nil,
            paused: true,
            remainingSeconds: duration(phase) - 10
        ))
        #expect(notifications.pendingCalls.last == .cancel(phase: storePhase(phase)))

        clock.advance(by: 10_000)
        timer.reconcileWithCurrentTime()

        #expect(timer.state.paused)
        #expect(timer.state.remainingSeconds == duration(phase) - 10)
        #expect(savedState() == timer.state)
    }

    @Test(arguments: TimedPhase.allCases)
    func resumeContinuesFromRemainingTime(_ phase: TimedPhase) {
        let timer = makeRunning(phase)
        clock.advance(by: 10)
        timer.pauseOrResume()
        clock.advance(by: 500)
        let resumedAt = clock.now

        timer.pauseOrResume()

        let deadline = resumedAt.addingTimeInterval(TimeInterval(duration(phase) - 10))
        #expect(timer.state.ignoringCycle == TimerStore.TimerState(
            phase: storePhase(phase),
            endTimestamp: deadline,
            paused: false,
            remainingSeconds: nil
        ))
        #expect(notifications.pendingCalls.last == .schedule(phase: storePhase(phase), deadline: deadline, now: resumedAt))
    }

    @Test func pauseIsIgnoredWhenIdle() {
        let timer = makeTimer()

        timer.pauseOrResume()

        #expect(timer.state == TimerStore.TimerState())
        #expect(notifications.pendingCalls.isEmpty)
    }

    @Test func pauseIsIgnoredWhileWaiting() {
        let timer = makeWaitingForBreak()
        let callCount = notifications.pendingCalls.count

        timer.pauseOrResume()

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(phase: .waitingForAConfirm))
        #expect(notifications.pendingCalls.count == callCount)
    }

    @Test func pauseAtExpiryCompletesInsteadOfAddingTime() {
        let timer = makeRunning(.focus)
        clock.advance(by: TimeInterval(focusSeconds))

        timer.pauseOrResume()

        withKnownIssue("Pause at or after expiry stores 1 s remaining instead of completing; owned by I12") {
            #expect(timer.state.phase == .waitingForAConfirm)
        }
    }

    // MARK: Cancel

    @Test(arguments: CancelStart.allCases)
    func cancelReturnsToIdleKeepingConfiguration(_ start: CancelStart) {
        let timer: TimerStore
        switch start {
        case .runningFocus:
            timer = makeRunning(.focus)
        case .pausedFocus:
            timer = makeRunning(.focus)
            timer.pauseOrResume()
        case .waitingForBreak:
            timer = makeWaitingForBreak()
        case .runningBreak:
            timer = makeRunning(.breakTime)
        case .pausedBreak:
            timer = makeRunning(.breakTime)
            timer.pauseOrResume()
        }

        timer.cancel()

        #expect(timer.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
        #expect(timer.configuration == TimerStore.Configuration(
            durationASeconds: focusSeconds,
            durationBSeconds: breakSeconds
        ))
        #expect(notifications.pendingCalls.last == .cancelAll)
    }

    // MARK: Delayed reconciliation

    @Test func delayedFocusReconciliationOnlyEntersWaiting() {
        let timer = makeRunning(.focus)

        clock.advance(by: TimeInterval(focusSeconds + breakSeconds + 3_600))
        timer.reconcileWithCurrentTime()

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(phase: .waitingForAConfirm))
        #expect(notifications.pendingCalls.count == 1)
    }

    @Test func delayedBreakReconciliationOnlyReturnsToIdle() {
        let timer = makeRunning(.breakTime)
        let callCount = notifications.pendingCalls.count

        clock.advance(by: TimeInterval(breakSeconds + focusSeconds + 3_600))
        timer.reconcileWithCurrentTime()
        timer.reconcileWithCurrentTime()

        #expect(timer.state == TimerStore.TimerState())
        // Completion cancels the pending Break request once; the second reconcile does nothing.
        #expect(Array(notifications.pendingCalls.dropFirst(callCount)) == [.cancel(phase: .runningB)])
    }
}

extension TimerStoreTransitionTests {
    func relaunch() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
    }

    var savedDurations: TimerStore.Configuration {
        TimerStore.Configuration(durationASeconds: focusSeconds, durationBSeconds: breakSeconds)
    }

    // MARK: Relaunch from the saved store

    @Test(arguments: TimedPhase.allCases)
    func relaunchBeforeDeadlineRestoresRunningPhase(_ phase: TimedPhase) {
        let timer = makeRunning(phase)
        let runningState = timer.state
        let callCount = notifications.pendingCalls.count
        clock.advance(by: 10)

        let relaunched = relaunch()

        #expect(relaunched.state == runningState)
        #expect(relaunched.configuration == savedDurations)
        #expect(notifications.pendingCalls.count == callCount)
    }

    @Test func relaunchAfterFocusDeadlineWaitsForConfirmation() {
        _ = makeRunning(.focus)
        clock.advance(by: TimeInterval(focusSeconds + 1_000))

        let relaunched = relaunch()

        #expect(relaunched.state.ignoringCycle == TimerStore.TimerState(phase: .waitingForAConfirm))
        #expect(savedState() == relaunched.state)
        #expect(notifications.pendingCalls.count == 1)
    }

    @Test func relaunchAfterBreakDeadlineReturnsToIdle() {
        _ = makeRunning(.breakTime)
        clock.advance(by: TimeInterval(breakSeconds + 1_000))

        let relaunched = relaunch()

        #expect(relaunched.state == TimerStore.TimerState())
        #expect(relaunched.configuration == savedDurations)
        #expect(savedState() == TimerStore.TimerState())
    }

    @Test(arguments: TimedPhase.allCases)
    func relaunchWhilePausedKeepsRemainingTime(_ phase: TimedPhase) {
        let timer = makeRunning(phase)
        clock.advance(by: 10)
        timer.pauseOrResume()
        clock.advance(by: 10_000)

        let relaunched = relaunch()

        #expect(relaunched.state.ignoringCycle == TimerStore.TimerState(
            phase: storePhase(phase),
            endTimestamp: nil,
            paused: true,
            remainingSeconds: duration(phase) - 10
        ))
    }

    @Test func relaunchWhileWaitingStaysWaiting() {
        _ = makeWaitingForBreak()
        clock.advance(by: 10_000)

        let relaunched = relaunch()

        #expect(relaunched.state.ignoringCycle == TimerStore.TimerState(phase: .waitingForAConfirm))
        #expect(relaunched.configuration == savedDurations)
    }

    // MARK: Notification OK path

    @Test func notificationOKAfterFocusExpiryStartsBreakOnce() {
        let timer = makeRunning(.focus)
        clock.advance(by: TimeInterval(focusSeconds + 5))
        let confirmedAt = clock.now

        timer.startBreakFromNotification(cycleID: timer.state.cycleID)

        let breakState = TimerStore.TimerState(
            phase: .runningB,
            endTimestamp: confirmedAt.addingTimeInterval(TimeInterval(breakSeconds)),
            paused: false,
            remainingSeconds: nil
        )
        #expect(timer.state.ignoringCycle == breakState)
        #expect(notifications.pendingCalls.last == .schedule(
            phase: .runningB,
            deadline: confirmedAt.addingTimeInterval(TimeInterval(breakSeconds)),
            now: confirmedAt
        ))

        let callCount = notifications.pendingCalls.count
        clock.advance(by: 2)
        timer.startBreakFromNotification(cycleID: timer.state.cycleID)

        #expect(timer.state.ignoringCycle == breakState)
        #expect(notifications.pendingCalls.count == callCount)
    }

    @Test func notificationOKBeforeFocusExpiryDoesNothing() {
        let timer = makeRunning(.focus)
        let runningState = timer.state
        clock.advance(by: 10)

        timer.startBreakFromNotification(cycleID: timer.state.cycleID)

        #expect(timer.state == runningState)
        #expect(notifications.pendingCalls.count == 1)
    }

    @Test func notificationOKWhilePausedDoesNothing() {
        let timer = makeRunning(.focus)
        timer.pauseOrResume()
        let pausedState = timer.state
        clock.advance(by: TimeInterval(focusSeconds + 5))

        timer.startBreakFromNotification(cycleID: timer.state.cycleID)

        #expect(timer.state == pausedState)
    }

    @Test func notificationOKWhenIdleDoesNothing() {
        let timer = makeTimer()

        timer.startBreakFromNotification(cycleID: timer.state.cycleID)

        #expect(timer.state == TimerStore.TimerState())
        #expect(notifications.pendingCalls.isEmpty)
    }

    // MARK: Display countdown

    @Test func displayWhileRunningRoundsUp() {
        let timer = makeRunning(.focus)
        #expect(timer.displayedSeconds == focusSeconds)

        clock.advance(by: 0.4)
        timer.reconcileWithCurrentTime()
        #expect(timer.displayedSeconds == focusSeconds)

        clock.advance(by: 0.6)
        timer.reconcileWithCurrentTime()
        #expect(timer.displayedSeconds == focusSeconds - 1)
    }

    @Test func displayWhilePausedShowsRemainingTime() {
        let timer = makeRunning(.focus)
        clock.advance(by: 10.5)
        timer.pauseOrResume()
        #expect(timer.displayedSeconds == focusSeconds - 10)

        clock.advance(by: 1_000)
        timer.reconcileWithCurrentTime()
        #expect(timer.displayedSeconds == focusSeconds - 10)
    }

    @Test func displayIsZeroWhileWaiting() {
        let timer = makeWaitingForBreak()

        #expect(timer.displayedSeconds == 0)
    }

    @Test func displayIsNilWhenIdle() {
        let timer = makeTimer()
        #expect(timer.displayedSeconds == nil)

        timer.startFocus()
        timer.cancel()
        #expect(timer.displayedSeconds == nil)
    }
}

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
            : TimerStore.TimerState()
        #expect(timer.state.ignoringCycle == expected)
        #expect(savedState()?.ignoringCycle == expected)
        #expect(notifications.pendingCalls == [.cancelAll])
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    // MARK: Stray fields

    @Test(arguments: [TimerStore.Phase.idle, .waitingForAConfirm])
    func strayTimingFieldsAreRemovedWhenNotRunning(_ phase: TimerStore.Phase) {
        seed(state: TimerStore.TimerState(
            phase: phase,
            endTimestamp: clock.now.addingTimeInterval(30),
            paused: true,
            remainingSeconds: 10
        ))

        let timer = load()

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(phase: phase))
        #expect(savedState()?.ignoringCycle == TimerStore.TimerState(phase: phase))
        #expect(notifications.pendingCalls.isEmpty)
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

enum UnversionedState: CaseIterable, Sendable {
    case idle
    case runningFocus
    case runningBreak
    case pausedFocus
    case pausedBreak
    case waitingForBreak
}

@MainActor
struct TimerStoreMigrationTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    let savedConfiguration = TimerStore.Configuration(durationASeconds: 25 * 60, durationBSeconds: 5 * 60)

    func seed(
        configuration: TimerStore.Configuration? = nil,
        state: TimerStore.TimerState? = nil,
        version: Data? = nil
    ) {
        if let configuration, let data = try? JSONEncoder().encode(configuration) {
            store.setData(data, forKey: "config")
        }
        if let state, let data = try? JSONEncoder().encode(state) {
            store.setData(data, forKey: "state")
        }
        if let version {
            store.setData(version, forKey: "schemaVersion")
        }
    }

    func versionData(_ version: Int) -> Data {
        (try? JSONEncoder().encode(version)) ?? Data()
    }

    /// Loads a store and returns it with the keys it wrote while loading.
    func load() -> (TimerStore, [String]) {
        let seededWrites = store.writtenKeys.count
        let timer = TimerStore(clock: clock, store: store, notifications: notifications)
        return (timer, Array(store.writtenKeys.dropFirst(seededWrites)))
    }

    func savedVersion() -> Int? {
        store.values["schemaVersion"].flatMap { try? JSONDecoder().decode(Int.self, from: $0) }
    }

    func state(_ unversioned: UnversionedState) -> TimerStore.TimerState {
        let deadline = clock.now.addingTimeInterval(600)
        return switch unversioned {
        case .idle: TimerStore.TimerState()
        case .runningFocus: TimerStore.TimerState(phase: .runningA, endTimestamp: deadline, paused: false, remainingSeconds: nil)
        case .runningBreak: TimerStore.TimerState(phase: .runningB, endTimestamp: deadline, paused: false, remainingSeconds: nil)
        case .pausedFocus: TimerStore.TimerState(phase: .runningA, endTimestamp: nil, paused: true, remainingSeconds: 1_494)
        case .pausedBreak: TimerStore.TimerState(phase: .runningB, endTimestamp: nil, paused: true, remainingSeconds: 200)
        case .waitingForBreak: TimerStore.TimerState(phase: .waitingForAConfirm)
        }
    }

    // MARK: Unversioned records

    @Test(arguments: UnversionedState.allCases)
    func unversionedRecordsKeepTheirValues(_ unversioned: UnversionedState) {
        seed(configuration: savedConfiguration, state: state(unversioned))
        let savedConfig = store.values["config"]
        let savedState = store.values["state"]
        let active = unversioned != .idle

        let (timer, writes) = load()

        #expect(timer.configuration == savedConfiguration)
        #expect(timer.state.ignoringCycle == state(unversioned))
        #expect((timer.state.cycleID != nil) == active)
        #expect(store.values["config"] == savedConfig)
        if active {
            // The 1 → 2 step saves the cycle ID it added.
            #expect(store.values["state"].flatMap { try? JSONDecoder().decode(TimerStore.TimerState.self, from: $0) } == timer.state)
        } else {
            #expect(store.values["state"] == savedState)
        }
        #expect(savedVersion() == TimerStore.currentSchemaVersion)
        #expect(writes == (active ? ["state", "schemaVersion"] : ["schemaVersion"]))
        #expect(notifications.pendingCalls.isEmpty)
        #expect(timer.statusMessage != TimerStore.repairNotice)
    }

    @Test(arguments: TimedPhase.allCases)
    func unversionedRunningStateWithPassedDeadlineReconciles(_ timed: TimedPhase) {
        seed(
            configuration: savedConfiguration,
            state: TimerStore.TimerState(
                phase: timed == .focus ? .runningA : .runningB,
                endTimestamp: clock.now.addingTimeInterval(-60),
                paused: false,
                remainingSeconds: nil
            )
        )

        let (timer, _) = load()

        let expected = timed == .focus ? TimerStore.TimerState(phase: .waitingForAConfirm) : TimerStore.TimerState()
        #expect(timer.state.ignoringCycle == expected)
        #expect(timer.configuration == savedConfiguration)
        #expect(savedVersion() == TimerStore.currentSchemaVersion)
    }

    @Test func unversionedRecordsAreMigratedThenRepaired() {
        seed(configuration: TimerStore.Configuration(durationASeconds: 30, durationBSeconds: 60))

        let (timer, _) = load()

        #expect(timer.configuration == TimerStore.Configuration(durationASeconds: 60, durationBSeconds: 60))
        #expect(savedVersion() == TimerStore.currentSchemaVersion)
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    // MARK: Fresh install and current version

    @Test func freshInstallWritesOnlyTheVersion() {
        let (timer, writes) = load()

        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == TimerStore.TimerState())
        #expect(writes == ["schemaVersion"])
        #expect(savedVersion() == TimerStore.currentSchemaVersion)
    }

    @Test func currentVersionLoadsWithoutWrites() {
        var pausedFocus = state(.pausedFocus)
        pausedFocus.cycleID = UUID()
        seed(configuration: savedConfiguration, state: pausedFocus, version: versionData(TimerStore.currentSchemaVersion))
        let savedValues = store.values

        let (timer, writes) = load()

        #expect(timer.configuration == savedConfiguration)
        #expect(timer.state == pausedFocus)
        #expect(writes.isEmpty)
        #expect(store.values == savedValues)
    }

    // MARK: Newer or unreadable versions

    @Test(arguments: [
        TimerStore.currentSchemaVersion + 1, -1,
    ])
    func unsupportedVersionUsesDefaultsAndWritesNothing(_ version: Int) {
        seed(configuration: savedConfiguration, state: state(.pausedFocus), version: versionData(version))
        let savedValues = store.values

        let (timer, writes) = load()

        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == TimerStore.TimerState())
        #expect(writes.isEmpty)
        #expect(store.values == savedValues)
        #expect(notifications.pendingCalls.isEmpty)
    }

    @Test func unreadableVersionUsesDefaultsAndWritesNothing() {
        seed(configuration: savedConfiguration, state: state(.pausedFocus), version: Data("not a version".utf8))
        let savedValues = store.values

        let (timer, writes) = load()

        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == TimerStore.TimerState())
        #expect(writes.isEmpty)
        #expect(store.values == savedValues)
    }
}

@MainActor
struct TimerStoreRecoveryTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    let savedConfiguration = TimerStore.Configuration(durationASeconds: 25 * 60, durationBSeconds: 5 * 60)
    let garbage = Data("not json".utf8)
    let cycleID = UUID()

    func encoded<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    func seed(config: Data? = nil, state: Data? = nil, version: Data? = TimerStoreRecoveryTests.encodedCurrentVersion) {
        if let config { store.setData(config, forKey: "config") }
        if let state { store.setData(state, forKey: "state") }
        if let version { store.setData(version, forKey: "schemaVersion") }
    }

    static var encodedCurrentVersion: Data {
        (try? JSONEncoder().encode(TimerStore.currentSchemaVersion)) ?? Data()
    }

    func load() -> (TimerStore, [String]) {
        let seededWrites = store.writtenKeys.count
        let timer = TimerStore(clock: clock, store: store, notifications: notifications)
        return (timer, Array(store.writtenKeys.dropFirst(seededWrites)))
    }

    func savedVersion() -> Int? {
        store.values["schemaVersion"].flatMap { try? JSONDecoder().decode(Int.self, from: $0) }
    }

    var runningFocus: TimerStore.TimerState {
        TimerStore.TimerState(phase: .runningA, endTimestamp: clock.now.addingTimeInterval(600), paused: false, remainingSeconds: nil, cycleID: cycleID)
    }

    // MARK: Unsupported versions

    @Test(arguments: [TimerStore.currentSchemaVersion + 1, -1])
    func unsupportedVersionShowsNoticeAndWritesNothing(_ version: Int) {
        seed(config: encoded(savedConfiguration), state: encoded(runningFocus), version: encoded(version))
        let savedValues = store.values

        let (timer, writes) = load()

        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.statusMessage == TimerStore.repairNotice)
        #expect(writes.isEmpty)
        #expect(store.values == savedValues)
    }

    @Test(arguments: [Data("not a version".utf8), Data("2".utf8) + Data("x".utf8)])
    func firstSaveAfterUnsupportedVersionWritesCurrentVersion(_ version: Data) {
        seed(config: encoded(savedConfiguration), state: encoded(runningFocus), version: version)
        let (timer, _) = load()

        timer.startOrConfirmBreak()

        #expect(savedVersion() == TimerStore.currentSchemaVersion)
        let (reloaded, writes) = load()
        #expect(reloaded.state.phase == .runningA)
        #expect(reloaded.configuration == TimerStore.Configuration())
        #expect(reloaded.statusMessage != TimerStore.repairNotice)
        #expect(writes.isEmpty)
    }

    @Test func versionIsWrittenOnlyOnTheFirstSave() {
        seed(config: encoded(savedConfiguration), version: encoded(TimerStore.currentSchemaVersion + 1))
        let (timer, _) = load()
        let seededVersionWrites = store.writtenKeys.filter { $0 == "schemaVersion" }.count

        timer.startOrConfirmBreak()
        let afterFirstSave = store.writtenKeys.filter { $0 == "schemaVersion" }.count - seededVersionWrites
        timer.pauseOrResume()
        timer.cancel()

        #expect(afterFirstSave == 1)
        #expect(store.writtenKeys.filter { $0 == "schemaVersion" }.count - seededVersionWrites == 1)
    }

    // MARK: One bad record

    @Test func corruptStateKeepsConfigurationAndIsReplaced() {
        seed(config: encoded(savedConfiguration), state: garbage)

        let (timer, writes) = load()

        #expect(timer.configuration == savedConfiguration)
        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.statusMessage == TimerStore.repairNotice)
        #expect(writes == ["state"])
        #expect(store.values["state"].flatMap { try? JSONDecoder().decode(TimerStore.TimerState.self, from: $0) } == TimerStore.TimerState())
        #expect(notifications.pendingCalls == [.cancelAll])
    }

    @Test func corruptConfigurationKeepsRunningStateAndDeadline() {
        let running = runningFocus
        seed(config: garbage, state: encoded(running))

        let (timer, writes) = load()

        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == running)
        #expect(timer.statusMessage == TimerStore.repairNotice)
        #expect(writes == ["config"])
        #expect(notifications.pendingCalls.isEmpty)
    }

    @Test func bothRecordsCorruptStillStarts() {
        seed(config: garbage, state: garbage)

        let (timer, _) = load()
        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.statusMessage == TimerStore.repairNotice)

        timer.startOrConfirmBreak()
        #expect(timer.state.phase == .runningA)
        let (reloaded, writes) = load()
        #expect(reloaded.state.phase == .runningA)
        #expect(reloaded.statusMessage != TimerStore.repairNotice)
        #expect(writes.isEmpty)
    }

    // MARK: Unknown or wrong-typed values

    @Test func unknownPhaseFallsBackWholeRecordAndKeepsConfiguration() {
        seed(config: encoded(savedConfiguration), state: Data(#"{"phase":"completed","paused":false}"#.utf8))

        let (timer, _) = load()

        #expect(timer.configuration == savedConfiguration)
        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    @Test func wrongTypedDurationsFallBackWholeRecordAndKeepState() {
        let paused = TimerStore.TimerState(phase: .runningA, endTimestamp: nil, paused: true, remainingSeconds: 900, cycleID: cycleID)
        seed(config: Data(#"{"durationASeconds":"25","durationBSeconds":300}"#.utf8), state: encoded(paused))

        let (timer, _) = load()

        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == paused)
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    // MARK: Regressions

    @Test func missingRecordsAtCurrentVersionShowNoNotice() {
        seed()

        let (timer, writes) = load()

        #expect(timer.statusMessage != TimerStore.repairNotice)
        #expect(writes.isEmpty)
    }
}

@MainActor
struct TimerStoreCycleTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
    }

    func makeWaitingForBreak() -> TimerStore {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        return timer
    }

    func savedState() -> TimerStore.TimerState? {
        store.values["state"].flatMap { try? JSONDecoder().decode(TimerStore.TimerState.self, from: $0) }
    }

    func seed(state: Data, version: Int) {
        store.setData(state, forKey: "state")
        if let data = try? JSONEncoder().encode(version) {
            store.setData(data, forKey: "schemaVersion")
        }
    }

    func encoded(_ state: TimerStore.TimerState) -> Data {
        (try? JSONEncoder().encode(state)) ?? Data()
    }

    // MARK: Lifetime of the cycle ID

    @Test func cycleIDLastsFromFocusStartThroughBreak() {
        let timer = makeTimer()
        #expect(timer.state.cycleID == nil)

        timer.startFocus()
        let cycleID = timer.state.cycleID
        #expect(cycleID != nil)
        #expect(savedState()?.cycleID == cycleID)

        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(timer.state.cycleID == cycleID)

        timer.startBreak()
        #expect(timer.state.phase == .runningB)
        #expect(timer.state.cycleID == cycleID)
        #expect(notifications.scheduledCycleIDs == [cycleID, cycleID])

        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        #expect(timer.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
    }

    @Test func pauseAndResumeKeepTheCycleID() {
        let timer = makeTimer()
        timer.startFocus()
        let cycleID = timer.state.cycleID

        timer.pauseOrResume()
        #expect(timer.state.cycleID == cycleID)
        timer.pauseOrResume()

        #expect(timer.state.cycleID == cycleID)
        #expect(notifications.scheduledCycleIDs == [cycleID, cycleID])
    }

    @Test func cancelRemovesTheCycleIDAndTheNextFocusGetsANewOne() {
        let timer = makeTimer()
        timer.startFocus()
        let firstCycle = timer.state.cycleID

        timer.cancel()
        #expect(timer.state.cycleID == nil)
        #expect(savedState()?.cycleID == nil)

        timer.startFocus()
        #expect(timer.state.cycleID != nil)
        #expect(timer.state.cycleID != firstCycle)
    }

    @Test func relaunchKeepsTheCycleID() {
        let timer = makeWaitingForBreak()
        let cycleID = timer.state.cycleID

        let relaunched = makeTimer()

        #expect(relaunched.state.cycleID == cycleID)
        #expect(relaunched.statusMessage != TimerStore.repairNotice)
    }

    // MARK: Notification action provenance

    @Test func matchingActionStartsBreak() {
        let timer = makeWaitingForBreak()

        timer.startBreakFromNotification(cycleID: timer.state.cycleID)

        #expect(timer.state.phase == .runningB)
    }

    @Test func matchingActionAfterFocusExpiredWhileSuspendedStartsBreak() {
        let timer = makeTimer()
        timer.startFocus()
        let cycleID = timer.state.cycleID
        clock.advance(by: 600)

        timer.startBreakFromNotification(cycleID: cycleID)

        #expect(timer.state.phase == .runningB)
        #expect(timer.state.cycleID == cycleID)
    }

    @Test func actionFromAnEarlierCycleCannotStartBreak() {
        let timer = makeTimer()
        timer.startFocus()
        let oldCycle = timer.state.cycleID
        timer.cancel()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        let waiting = timer.state
        let saved = store.values["state"]
        let scheduleCount = notifications.scheduledCycleIDs.count

        timer.startBreakFromNotification(cycleID: oldCycle)

        #expect(timer.state == waiting)
        #expect(store.values["state"] == saved)
        #expect(notifications.scheduledCycleIDs.count == scheduleCount)
    }

    @Test func actionFromAnEarlierCycleDoesNotTouchARunningFocus() {
        let timer = makeTimer()
        timer.startFocus()
        let oldCycle = timer.state.cycleID
        timer.cancel()
        timer.startFocus()
        let running = timer.state

        timer.startBreakFromNotification(cycleID: oldCycle)

        #expect(timer.state == running)
    }

    @Test(arguments: [nil, UUID()] as [UUID?])
    func actionWithoutOrWithUnknownIDIsIgnored(_ cycleID: UUID?) {
        let timer = makeWaitingForBreak()
        let waiting = timer.state
        let scheduleCount = notifications.scheduledCycleIDs.count

        timer.startBreakFromNotification(cycleID: cycleID)

        #expect(timer.state == waiting)
        #expect(notifications.scheduledCycleIDs.count == scheduleCount)
    }

    @Test func duplicateActionAfterBreakStartedDoesNothing() {
        let timer = makeWaitingForBreak()
        let cycleID = timer.state.cycleID
        timer.startBreakFromNotification(cycleID: cycleID)
        let breakState = timer.state
        let scheduleCount = notifications.scheduledCycleIDs.count
        clock.advance(by: 5)

        timer.startBreakFromNotification(cycleID: cycleID)

        #expect(timer.state == breakState)
        #expect(notifications.scheduledCycleIDs.count == scheduleCount)
    }

    @Test func notificationUserInfoCarriesTheCycleID() {
        let cycleID = UUID()

        #expect(NotificationScheduler.cycleID(in: [NotificationScheduler.cycleIDKey: cycleID.uuidString]) == cycleID)
        #expect(NotificationScheduler.cycleID(in: [:]) == nil)
        #expect(NotificationScheduler.cycleID(in: [NotificationScheduler.cycleIDKey: "not a uuid"]) == nil)
    }

    // MARK: Migration 1 → 2

    @Test(arguments: [UnversionedState.runningFocus, .runningBreak, .pausedFocus, .pausedBreak, .waitingForBreak])
    func version1ActiveStateGetsACycleIDWithoutNotice(_ fixture: UnversionedState) {
        let deadline = clock.now.addingTimeInterval(600)
        let state: TimerStore.TimerState = switch fixture {
        case .idle: TimerStore.TimerState()
        case .runningFocus: TimerStore.TimerState(phase: .runningA, endTimestamp: deadline)
        case .runningBreak: TimerStore.TimerState(phase: .runningB, endTimestamp: deadline)
        case .pausedFocus: TimerStore.TimerState(phase: .runningA, paused: true, remainingSeconds: 300)
        case .pausedBreak: TimerStore.TimerState(phase: .runningB, paused: true, remainingSeconds: 30)
        case .waitingForBreak: TimerStore.TimerState(phase: .waitingForAConfirm)
        }
        seed(state: encoded(state), version: 1)

        let timer = makeTimer()

        #expect(timer.state.ignoringCycle == state)
        #expect(timer.state.cycleID != nil)
        #expect(savedState() == timer.state)
        #expect(store.values["schemaVersion"] == (try? JSONEncoder().encode(2)))
        #expect(timer.statusMessage != TimerStore.repairNotice)
        #expect(notifications.pendingCalls.isEmpty)
    }

    @Test func version1IdleStateGetsNoCycleID() {
        seed(state: encoded(TimerStore.TimerState()), version: 1)

        let timer = makeTimer()

        #expect(timer.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
        #expect(store.writtenKeys.filter { $0 == "state" }.count == 1)
    }

    // MARK: Repair

    @Test func version2ActiveStateWithoutIDIsRepairedWithNotice() {
        let deadline = clock.now.addingTimeInterval(600)
        let running = TimerStore.TimerState(phase: .runningA, endTimestamp: deadline)
        seed(state: encoded(running), version: 2)

        let timer = makeTimer()

        #expect(timer.state.ignoringCycle == running)
        #expect(timer.state.cycleID != nil)
        #expect(savedState() == timer.state)
        #expect(timer.statusMessage == TimerStore.repairNotice)
        #expect(notifications.pendingCalls.isEmpty)
    }

    @Test func idleWithACycleIDIsRepairedWithNotice() {
        seed(state: encoded(TimerStore.TimerState(cycleID: UUID())), version: 2)

        let timer = makeTimer()

        #expect(timer.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    @Test func unreadableCycleIDMakesTheStateUnreadable() {
        seed(state: Data(#"{"phase":"waitingForAConfirm","paused":false,"cycleID":"abc"}"#.utf8), version: 2)

        let timer = makeTimer()

        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }
}

enum CleanupPhase: CaseIterable, Sendable {
    case idle, runningFocus, pausedFocus, waiting, runningBreak, pausedBreak
}

@MainActor
struct TimerStoreAlertCleanupTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
    }

    /// Removals of delivered alerts made after this point.
    func deliveredCalls(after mark: Int) -> [RecordingNotificationScheduler.Call] {
        Array(notifications.calls.dropFirst(mark)).filter { notifications.deliveredCalls.contains($0) }
    }

    func makeWaitingForBreak() -> TimerStore {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        return timer
    }

    // MARK: Events

    @Test func focusStartRemovesAllDeliveredAlerts() {
        let timer = makeTimer()
        let mark = notifications.calls.count

        timer.startFocus()

        #expect(deliveredCalls(after: mark) == [.removeAllDelivered])
    }

    @Test func breakStartInTheAppRemovesTheDeliveredFocusAlert() {
        let timer = makeWaitingForBreak()
        let mark = notifications.calls.count

        timer.startOrConfirmBreak()

        #expect(timer.state.phase == .runningB)
        #expect(deliveredCalls(after: mark) == [.removeDelivered(phase: .runningA)])
    }

    @Test func breakStartFromAMatchingActionRemovesTheDeliveredFocusAlert() {
        let timer = makeWaitingForBreak()
        let mark = notifications.calls.count

        timer.startBreakFromNotification(cycleID: timer.state.cycleID)

        #expect(timer.state.phase == .runningB)
        #expect(deliveredCalls(after: mark) == [.removeDelivered(phase: .runningA)])
    }

    @Test(arguments: [nil, UUID()] as [UUID?])
    func ignoredActionRemovesNothing(_ cycleID: UUID?) {
        let timer = makeWaitingForBreak()
        let mark = notifications.calls.count

        timer.startBreakFromNotification(cycleID: cycleID)

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(notifications.calls.count == mark)
    }

    @Test func duplicateActionAfterBreakStartedRemovesNothing() {
        let timer = makeWaitingForBreak()
        let cycleID = timer.state.cycleID
        timer.startBreakFromNotification(cycleID: cycleID)
        let mark = notifications.calls.count

        timer.startBreakFromNotification(cycleID: cycleID)

        #expect(notifications.calls.count == mark)
    }

    @Test func focusCompletionKeepsTheCurrentAlert() {
        let timer = makeTimer()
        timer.startFocus()
        let mark = notifications.calls.count
        clock.advance(by: 60)

        timer.reconcileWithCurrentTime()

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(notifications.calls.count == mark)
    }

    @Test func breakCompletionRemovesOnlyThePendingBreakRequest() {
        let timer = makeWaitingForBreak()
        timer.startBreak()
        let mark = notifications.calls.count
        clock.advance(by: 60)

        timer.reconcileWithCurrentTime()

        #expect(timer.state == TimerStore.TimerState())
        #expect(Array(notifications.calls.dropFirst(mark)) == [.cancel(phase: .runningB)])
    }

    @Test func cancelRemovesAllPendingAndDeliveredAlerts() {
        let timer = makeWaitingForBreak()
        let mark = notifications.calls.count

        timer.cancel()

        #expect(Array(notifications.calls.dropFirst(mark)) == [.cancelAll, .removeAllDelivered])
    }

    @Test func pauseAndResumeRemoveNoDeliveredAlerts() {
        let timer = makeTimer()
        timer.startFocus()
        let mark = notifications.calls.count

        timer.pauseOrResume()
        timer.pauseOrResume()

        #expect(deliveredCalls(after: mark).isEmpty)
    }

    @Test func tickerReconcileRemovesNoDeliveredAlerts() {
        let timer = makeTimer()
        timer.startFocus()
        let mark = notifications.calls.count

        for _ in 0..<3 {
            clock.advance(by: 1)
            timer.reconcileWithCurrentTime()
        }

        #expect(notifications.calls.count == mark)
    }

    // MARK: Launch and activation

    func reach(_ phase: CleanupPhase) -> TimerStore {
        let timer = makeTimer()
        switch phase {
        case .idle:
            break
        case .runningFocus:
            timer.startFocus()
        case .pausedFocus:
            timer.startFocus()
            timer.pauseOrResume()
        case .waiting:
            return makeWaitingForBreak()
        case .runningBreak, .pausedBreak:
            let waiting = makeWaitingForBreak()
            waiting.startBreak()
            if phase == .pausedBreak {
                waiting.pauseOrResume()
            }
            return waiting
        }
        return timer
    }

    func expectedCleanup(_ phase: CleanupPhase) -> [RecordingNotificationScheduler.Call] {
        switch phase {
        case .idle, .runningFocus, .pausedFocus:
            [.removeDelivered(phase: .runningA), .removeDelivered(phase: .runningB)]
        case .waiting:
            [.removeDelivered(phase: .runningB)]
        case .runningBreak, .pausedBreak:
            [.removeDelivered(phase: .runningA)]
        }
    }

    @Test(arguments: CleanupPhase.allCases)
    func activationRemovesAlertsThatDoNotMatchThePhase(_ phase: CleanupPhase) {
        let timer = reach(phase)
        let mark = notifications.calls.count

        timer.activate()

        #expect(Array(notifications.calls.dropFirst(mark)) == expectedCleanup(phase))
    }

    @Test(arguments: CleanupPhase.allCases)
    func launchRemovesAlertsThatDoNotMatchThePhase(_ phase: CleanupPhase) {
        _ = reach(phase)
        let mark = notifications.calls.count

        _ = makeTimer()

        #expect(Array(notifications.calls.dropFirst(mark)) == expectedCleanup(phase))
    }

    @Test func activationAfterBreakEndedInTheBackgroundRemovesTheBreakAlert() {
        let timer = makeWaitingForBreak()
        timer.startBreak()
        clock.advance(by: 600)
        let mark = notifications.calls.count

        timer.activate()

        #expect(timer.state == TimerStore.TimerState())
        #expect(Array(notifications.calls.dropFirst(mark)) == [
            .cancel(phase: .runningB),
            .removeDelivered(phase: .runningA),
            .removeDelivered(phase: .runningB),
        ])
    }

    @Test func activationAfterFocusEndedInTheBackgroundKeepsTheFocusAlert() {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 600)
        let mark = notifications.calls.count

        timer.activate()

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(Array(notifications.calls.dropFirst(mark)) == [.removeDelivered(phase: .runningB)])
    }
}
