import Foundation
import Testing
@testable import FocusTimer

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
        // Start's .cancelAll and the Focus schedule, nothing more.
        #expect(notifications.pendingCalls.count == 2)
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
        // Start's .cancelAll and the Focus schedule, nothing more.
        #expect(notifications.pendingCalls.count == 2)
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
        // Start's .cancelAll and the Focus schedule, nothing more.
        #expect(notifications.pendingCalls.count == 2)
    }

    @Test func breakNeverStartsByItself() {
        let timer = makeWaitingForBreak()

        for _ in 0..<3 {
            clock.advance(by: 10_000)
            timer.reconcileWithCurrentTime()
        }

        #expect(timer.state.phase == .waitingForAConfirm)
        // Start's .cancelAll and the Focus schedule, nothing more.
        #expect(notifications.pendingCalls.count == 2)
    }

    @Test func breakExpiryCompletesTheCycleKeepingConfiguration() {
        let timer = makeRunning(.breakTime)

        clock.advance(by: TimeInterval(breakSeconds))
        timer.reconcileWithCurrentTime()

        // Since I13 a finished Break enters completed instead of idle.
        #expect(timer.state.ignoringCycle == TimerStore.TimerState(phase: .completed))
        #expect(timer.configuration == TimerStore.Configuration(
            durationASeconds: focusSeconds,
            durationBSeconds: breakSeconds
        ))
        #expect(savedState() == timer.state)
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

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(phase: .waitingForAConfirm))
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
        // Start's .cancelAll and the Focus schedule, nothing more.
        #expect(notifications.pendingCalls.count == 2)
    }

    @Test func delayedBreakReconciliationOnlyCompletesTheCycle() {
        let timer = makeRunning(.breakTime)
        let callCount = notifications.pendingCalls.count

        clock.advance(by: TimeInterval(breakSeconds + focusSeconds + 3_600))
        timer.reconcileWithCurrentTime()
        timer.reconcileWithCurrentTime()

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(phase: .completed))
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
        // Start's .cancelAll and the Focus schedule, nothing more.
        #expect(notifications.pendingCalls.count == 2)
    }

    @Test func relaunchAfterBreakDeadlineCompletesTheCycle() {
        _ = makeRunning(.breakTime)
        clock.advance(by: TimeInterval(breakSeconds + 1_000))

        let relaunched = relaunch()

        #expect(relaunched.state.ignoringCycle == TimerStore.TimerState(phase: .completed))
        #expect(relaunched.configuration == savedDurations)
        #expect(savedState() == relaunched.state)
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
        // Start's .cancelAll and the Focus schedule, nothing more.
        #expect(notifications.pendingCalls.count == 2)
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
