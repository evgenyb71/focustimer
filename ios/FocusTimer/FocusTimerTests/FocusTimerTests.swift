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
        #expect(notifications.calls == [
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
        #expect(notifications.calls.last == .cancel(phase: .runningA))
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
        #expect(notifications.calls.last == .schedule(
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
        #expect(notifications.calls.last == .cancelAll)
    }

    @Test func breakIsScheduledOnlyAfterConfirmation() {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)

        timer.reconcileWithCurrentTime()

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(notifications.calls.count == 1)

        let confirmedAt = clock.now
        timer.startBreak()

        #expect(timer.state.phase == .runningB)
        #expect(notifications.calls.last == .schedule(
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
    let breakSeconds = 30

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

        #expect(timer.state == TimerStore.TimerState(
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

    @Test func startFocusIsIgnoredOutsideIdle() {
        let running = makeRunning(.focus)
        let runningState = running.state
        running.startFocus()
        #expect(running.state == runningState)

        let waiting = makeWaitingForBreak()
        let callCount = notifications.calls.count
        waiting.startFocus()
        #expect(waiting.state.phase == .waitingForAConfirm)
        #expect(notifications.calls.count == callCount)
    }

    @Test func startBreakIsIgnoredOutsideWaiting() {
        let idle = makeTimer()
        idle.startBreak()
        #expect(idle.state.phase == .idle)

        let running = makeRunning(.focus)
        let runningState = running.state
        running.startBreak()
        #expect(running.state == runningState)
    }

    @Test func focusExpiryWaitsForConfirmation() {
        let timer = makeRunning(.focus)
        clock.advance(by: TimeInterval(focusSeconds - 1))
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .runningA)

        clock.advance(by: 1)
        timer.reconcileWithCurrentTime()

        #expect(timer.state == TimerStore.TimerState(phase: .waitingForAConfirm))
        #expect(savedState() == timer.state)
        #expect(notifications.calls.count == 1)
    }

    @Test func breakNeverStartsByItself() {
        let timer = makeWaitingForBreak()

        for _ in 0..<3 {
            clock.advance(by: 10_000)
            timer.reconcileWithCurrentTime()
        }

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(notifications.calls.count == 1)
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

        #expect(timer.state == TimerStore.TimerState(
            phase: storePhase(phase),
            endTimestamp: nil,
            paused: true,
            remainingSeconds: duration(phase) - 10
        ))
        #expect(notifications.calls.last == .cancel(phase: storePhase(phase)))

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
        #expect(timer.state == TimerStore.TimerState(
            phase: storePhase(phase),
            endTimestamp: deadline,
            paused: false,
            remainingSeconds: nil
        ))
        #expect(notifications.calls.last == .schedule(phase: storePhase(phase), deadline: deadline, now: resumedAt))
    }

    @Test func pauseIsIgnoredOutsideRunningPhases() {
        let idle = makeTimer()
        idle.pauseOrResume()
        #expect(idle.state == TimerStore.TimerState())

        let waiting = makeWaitingForBreak()
        let callCount = notifications.calls.count
        waiting.pauseOrResume()
        #expect(waiting.state == TimerStore.TimerState(phase: .waitingForAConfirm))
        #expect(notifications.calls.count == callCount)
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
        #expect(notifications.calls.last == .cancelAll)
    }

    // MARK: Delayed reconciliation

    @Test func delayedFocusReconciliationOnlyEntersWaiting() {
        let timer = makeRunning(.focus)

        clock.advance(by: TimeInterval(focusSeconds + breakSeconds + 3_600))
        timer.reconcileWithCurrentTime()

        #expect(timer.state == TimerStore.TimerState(phase: .waitingForAConfirm))
        #expect(notifications.calls.count == 1)
    }

    @Test func delayedBreakReconciliationOnlyReturnsToIdle() {
        let timer = makeRunning(.breakTime)
        let callCount = notifications.calls.count

        clock.advance(by: TimeInterval(breakSeconds + focusSeconds + 3_600))
        timer.reconcileWithCurrentTime()
        timer.reconcileWithCurrentTime()

        #expect(timer.state == TimerStore.TimerState())
        #expect(notifications.calls.count == callCount)
    }
}
