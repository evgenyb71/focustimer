import Foundation
import Testing
@testable import FocusTimer

/// What a launch does with each saved state. Each `makeTimer()` after the first stands for a new process.
@MainActor
struct TimerStoreLaunchPolicyTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
    }

    /// Focus has ended, and the app has seen it.
    func makeWaiting() -> TimerStore {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        return timer
    }

    /// Break has ended, and the app has seen it.
    func makeCompleted() -> TimerStore {
        let timer = makeWaiting()
        timer.startBreak()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        return timer
    }

    func savedState() -> TimerStore.TimerState? {
        store.values["state"].flatMap { try? JSONDecoder().decode(TimerStore.TimerState.self, from: $0) }
    }

    // MARK: Finished states reset

    @Test func aSavedWaitingStateResetsToIdle() {
        _ = makeWaiting()
        let calls = notifications.calls.count

        let relaunched = makeTimer()

        #expect(relaunched.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
        #expect(relaunched.endState == nil)
        #expect(relaunched.displayedSeconds == nil)
        #expect(relaunched.noticeMessage == nil)
        #expect(relaunched.primaryButtonTitle == "Start")
        #expect(notifications.calls.dropFirst(calls).contains(.cancelAll))
        #expect(notifications.calls.dropFirst(calls).contains(.removeAllDelivered))
    }

    @Test func aSavedCompletedStateResetsToIdle() {
        _ = makeCompleted()
        let calls = notifications.calls.count

        let relaunched = makeTimer()

        #expect(relaunched.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
        #expect(relaunched.endState == nil)
        #expect(relaunched.noticeMessage == nil)
        #expect(!relaunched.canFinish)
        #expect(relaunched.primaryButtonTitle == "Start")
        #expect(notifications.calls.dropFirst(calls).contains(.cancelAll))
        #expect(notifications.calls.dropFirst(calls).contains(.removeAllDelivered))
    }

    @Test func aResetStaysIdleOnTheNextLaunch() {
        _ = makeCompleted()
        _ = makeTimer()

        let relaunched = makeTimer()

        #expect(relaunched.state == TimerStore.TimerState())
        #expect(relaunched.noticeMessage == nil)
    }

    // MARK: Durations

    @Test func aResetKeepsTheSavedDurations() {
        let timer = makeTimer()
        timer.configuration.durationASeconds = 300
        timer.configuration.durationBSeconds = 600
        timer.startFocus()
        clock.advance(by: 300)
        timer.reconcileWithCurrentTime()

        let relaunched = makeTimer()

        #expect(relaunched.state.phase == .idle)
        #expect(relaunched.configuration == TimerStore.Configuration(durationASeconds: 300, durationBSeconds: 600))
    }

    @Test func aResetDropsDurationEditsThatWereNotStarted() {
        let timer = makeCompleted()
        let saved = timer.configuration
        timer.configuration.durationBSeconds = saved.durationBSeconds + 120

        let relaunched = makeTimer()

        #expect(relaunched.configuration == saved)
    }

    // MARK: Working states are restored

    @Test(arguments: TimedPhase.allCases)
    func aRunningPhaseWithItsDeadlineAheadIsRestored(_ phase: TimedPhase) {
        let timer = phase == .focus ? makeTimer() : makeWaiting()
        if phase == .focus {
            timer.startFocus()
        } else {
            timer.startBreak()
        }
        let state = timer.state
        clock.advance(by: 20)
        let calls = notifications.calls.count

        let relaunched = makeTimer()

        #expect(relaunched.state == state)
        #expect(relaunched.displayedSeconds == 40)
        #expect(relaunched.noticeMessage == nil)
        #expect(!notifications.calls.dropFirst(calls).contains(.cancelAll))
        #expect(!notifications.calls.dropFirst(calls).contains(.removeAllDelivered))
    }

    @Test(arguments: TimedPhase.allCases)
    func aPausedPhaseIsRestored(_ phase: TimedPhase) {
        let timer = phase == .focus ? makeTimer() : makeWaiting()
        if phase == .focus {
            timer.startFocus()
        } else {
            timer.startBreak()
        }
        clock.advance(by: 20)
        timer.pauseOrResume()
        let state = timer.state
        clock.advance(by: 3_600)
        let calls = notifications.calls.count

        let relaunched = makeTimer()

        #expect(relaunched.state == state)
        #expect(relaunched.displayedSeconds == 40)
        #expect(!notifications.calls.dropFirst(calls).contains(.cancelAll))
        #expect(!notifications.calls.dropFirst(calls).contains(.removeAllDelivered))
    }

    // MARK: Expiry while closed shows the end screen once

    @Test func focusThatExpiredWhileClosedShowsItsEndOnceThenResets() {
        let timer = makeTimer()
        timer.startFocus()
        let cycleID = timer.state.cycleID
        clock.advance(by: 60)

        let firstLaunch = makeTimer()
        #expect(firstLaunch.state.phase == .waitingForAConfirm)
        #expect(firstLaunch.state.cycleID == cycleID)
        #expect(firstLaunch.endState == .focusComplete)

        let secondLaunch = makeTimer()
        #expect(secondLaunch.state == TimerStore.TimerState())
    }

    @Test func breakThatExpiredWhileClosedShowsItsEndOnceThenResets() {
        let timer = makeWaiting()
        timer.startBreak()
        let cycleID = timer.state.cycleID
        clock.advance(by: 60)

        let firstLaunch = makeTimer()
        #expect(firstLaunch.state.phase == .completed)
        #expect(firstLaunch.state.cycleID == cycleID)
        #expect(firstLaunch.endState == .breakComplete)
        #expect(firstLaunch.canFinish)

        let secondLaunch = makeTimer()
        #expect(secondLaunch.state == TimerStore.TimerState())
    }

    @Test func focusThatExpiredWhileClosedKeepsItsAlert() {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        let calls = notifications.calls.count

        _ = makeTimer()

        let launchCalls = notifications.calls.dropFirst(calls)
        #expect(!launchCalls.contains(.removeAllDelivered))
        #expect(!launchCalls.contains(.removeDelivered(phase: .runningA)))
    }

    @Test func breakThatExpiredWhileClosedKeepsItsAlert() {
        let timer = makeWaiting()
        timer.startBreak()
        clock.advance(by: 60)
        let calls = notifications.calls.count

        _ = makeTimer()

        let launchCalls = notifications.calls.dropFirst(calls)
        #expect(!launchCalls.contains(.removeAllDelivered))
        #expect(!launchCalls.contains(.removeDelivered(phase: .runningB)))
    }

    // MARK: Focus alert's OK

    @Test func okAfterFocusExpiredWhileClosedStartsBreak() {
        let timer = makeTimer()
        timer.startFocus()
        let cycleID = timer.state.cycleID
        clock.advance(by: 60)

        let launched = makeTimer()
        launched.startBreakFromNotification(cycleID: cycleID)

        #expect(launched.state.phase == .runningB)
        #expect(launched.state.cycleID == cycleID)
    }

    @Test func okAfterAResetDoesNothing() {
        let timer = makeWaiting()
        let cycleID = timer.state.cycleID

        let launched = makeTimer()
        let calls = notifications.calls.count
        launched.startBreakFromNotification(cycleID: cycleID)

        #expect(launched.state == TimerStore.TimerState())
        #expect(notifications.calls.count == calls)
    }

    // MARK: Staying in the same process

    @Test func activationKeepsTheWaitingState() {
        let timer = makeWaiting()
        let state = timer.state

        timer.activate()

        #expect(timer.state == state)
    }

    @Test func activationKeepsTheCompletedState() {
        let timer = makeCompleted()
        let state = timer.state

        timer.activate()

        #expect(timer.state == state)
    }

    // MARK: Repair

    @Test func aRepairedFinishedStateResetsAndKeepsItsNotice() {
        if let state = try? JSONEncoder().encode(TimerStore.TimerState(phase: .completed)),
           let version = try? JSONEncoder().encode(TimerStore.currentSchemaVersion) {
            store.setData(state, forKey: "state")
            store.setData(version, forKey: "schemaVersion")
        }

        let launched = makeTimer()

        #expect(launched.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
        #expect(launched.statusMessage == TimerStore.repairNotice)
    }

    // MARK: The next cycle

    @Test func aNewFocusAfterAResetStillWaitsForBreakConfirmation() {
        let timer = makeCompleted()
        let finishedCycle = timer.state.cycleID

        let relaunched = makeTimer()
        relaunched.startOrConfirmBreak()
        #expect(relaunched.state.phase == .runningA)
        #expect(relaunched.state.cycleID != nil)
        #expect(relaunched.state.cycleID != finishedCycle)

        clock.advance(by: 3_600)
        relaunched.reconcileWithCurrentTime()
        #expect(relaunched.state.phase == .waitingForAConfirm)
    }
}
