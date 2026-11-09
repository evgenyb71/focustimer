import Foundation
import Testing
@testable import FocusTimer

/// The Break alert's Restart action. Each `makeTimer()` after the first stands for a new process.
@MainActor
struct TimerStoreNotificationRestartTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer(secondsPerMinute: Int = 60) -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications, secondsPerMinute: secondsPerMinute)
    }

    func makeBreakRunning(on timer: TimerStore? = nil) -> TimerStore {
        let timer = timer ?? makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        timer.startBreak()
        return timer
    }

    func makeCompleted(on timer: TimerStore? = nil) -> TimerStore {
        let timer = makeBreakRunning(on: timer)
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        return timer
    }

    func savedState() -> TimerStore.TimerState? {
        store.values["state"].flatMap { try? JSONDecoder().decode(TimerStore.TimerState.self, from: $0) }
    }

    func savedConfiguration() -> TimerStore.Configuration? {
        store.values["config"].flatMap { try? JSONDecoder().decode(TimerStore.Configuration.self, from: $0) }
    }

    func expectRestartIsIgnored(
        _ timer: TimerStore,
        cycleID: UUID?,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let state = timer.state
        let writes = store.writtenKeys.count
        let calls = notifications.calls.count

        timer.restartFromNotification(cycleID: cycleID)

        #expect(timer.state == state, sourceLocation: sourceLocation)
        #expect(store.writtenKeys.count == writes, sourceLocation: sourceLocation)
        #expect(notifications.calls.count == calls, sourceLocation: sourceLocation)
    }

    // MARK: A valid Restart

    @Test func matchingRestartStartsOneFocus() throws {
        let timer = makeCompleted()
        let finishedCycle = try #require(timer.state.cycleID)
        timer.configuration.durationASeconds = 90
        let calls = notifications.calls.count
        let schedules = notifications.scheduledCycleIDs.count

        timer.restartFromNotification(cycleID: finishedCycle)

        let now = clock.now
        #expect(timer.state.phase == .runningA)
        #expect(!timer.state.paused)
        #expect(timer.state.endTimestamp == now.addingTimeInterval(120))
        let newCycle = try #require(timer.state.cycleID)
        #expect(newCycle != finishedCycle)
        #expect(savedState() == timer.state)
        #expect(savedConfiguration()?.durationASeconds == 120)
        #expect(Array(notifications.calls.dropFirst(calls)) == [
            .cancelAll,
            .removeAllDelivered,
            .schedule(phase: .runningA, deadline: now.addingTimeInterval(120), now: now),
        ])
        #expect(Array(notifications.scheduledCycleIDs.dropFirst(schedules)) == [newCycle])
    }

    @Test func matchingRestartAfterBreakEndedInTheBackgroundStartsFocus() {
        let timer = makeBreakRunning()
        let cycleID = timer.state.cycleID
        clock.advance(by: 600)

        timer.restartFromNotification(cycleID: cycleID)

        #expect(timer.state.phase == .runningA)
        #expect(timer.state.cycleID != cycleID)
    }

    @Test func matchingRestartAfterBreakEndedWhileClosedStartsFocusThatTheNextLaunchRestores() {
        let cycleID = makeBreakRunning().state.cycleID
        clock.advance(by: 60)

        let launched = makeTimer()
        #expect(launched.state.phase == .completed)
        launched.restartFromNotification(cycleID: cycleID)
        #expect(launched.state.phase == .runningA)
        let focus = launched.state

        clock.advance(by: 20)
        let relaunched = makeTimer()
        #expect(relaunched.state == focus)
        #expect(relaunched.displayedSeconds == 40)
    }

    @Test func theNewFocusStillWaitsForBreakConfirmation() {
        let timer = makeCompleted()
        timer.restartFromNotification(cycleID: timer.state.cycleID)

        clock.advance(by: 3_600)
        timer.reconcileWithCurrentTime()

        #expect(timer.state.phase == .waitingForAConfirm)
    }

    @Test func aShortMinuteShortensTheNewFocus() {
        let timer = makeTimer(secondsPerMinute: 10)
        timer.startFocus()
        clock.advance(by: 10)
        timer.reconcileWithCurrentTime()
        timer.startBreak()
        clock.advance(by: 10)
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .completed)

        timer.restartFromNotification(cycleID: timer.state.cycleID)

        #expect(timer.state.endTimestamp == clock.now.addingTimeInterval(10))
    }

    // MARK: Stale and duplicate actions

    @Test func restartFromAnEarlierCycleIsIgnored() {
        let timer = makeCompleted()
        let oldCycle = timer.state.cycleID
        timer.done()
        _ = makeCompleted(on: timer)

        expectRestartIsIgnored(timer, cycleID: oldCycle)
    }

    @Test func restartFromAnEarlierCycleLeavesANewerExpiredBreakUnreconciled() {
        let timer = makeCompleted()
        let oldCycle = timer.state.cycleID
        timer.done()
        _ = makeBreakRunning(on: timer)
        clock.advance(by: 60)
        #expect(timer.state.phase == .runningB)

        expectRestartIsIgnored(timer, cycleID: oldCycle)
    }

    @Test(arguments: [nil, UUID()] as [UUID?])
    func restartWithoutOrWithUnknownIDIsIgnored(_ cycleID: UUID?) {
        expectRestartIsIgnored(makeCompleted(), cycleID: cycleID)
    }

    @Test func repeatedRestartStartsNoSecondFocus() {
        let timer = makeCompleted()
        let finishedCycle = timer.state.cycleID
        timer.restartFromNotification(cycleID: finishedCycle)
        clock.advance(by: 5)

        expectRestartIsIgnored(timer, cycleID: finishedCycle)
    }

    @Test func doneFromTheSameAlertAfterRestartIsIgnored() {
        let timer = makeCompleted()
        let finishedCycle = timer.state.cycleID
        timer.restartFromNotification(cycleID: finishedCycle)
        let focus = timer.state
        let calls = notifications.calls.count

        timer.doneFromNotification(cycleID: finishedCycle)

        #expect(timer.state == focus)
        #expect(notifications.calls.count == calls)
    }

    @Test func restartAfterALaunchResetStartsNoFocus() {
        let cycleID = makeCompleted().state.cycleID

        let launched = makeTimer()
        #expect(launched.state == TimerStore.TimerState())

        expectRestartIsIgnored(launched, cycleID: cycleID)
    }

    // MARK: Restart before the cycle is complete

    @Test func restartIsIgnoredOutsideCompleted() {
        let timer = makeTimer()
        expectRestartIsIgnored(timer, cycleID: nil)

        timer.startFocus()
        expectRestartIsIgnored(timer, cycleID: timer.state.cycleID)
        timer.pauseOrResume()
        expectRestartIsIgnored(timer, cycleID: timer.state.cycleID)
        timer.pauseOrResume()

        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .waitingForAConfirm)
        expectRestartIsIgnored(timer, cycleID: timer.state.cycleID)

        timer.startBreak()
        expectRestartIsIgnored(timer, cycleID: timer.state.cycleID)
        timer.pauseOrResume()
        expectRestartIsIgnored(timer, cycleID: timer.state.cycleID)
    }
}
