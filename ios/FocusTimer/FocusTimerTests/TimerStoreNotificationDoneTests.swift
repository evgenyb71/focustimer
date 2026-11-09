import Foundation
import Testing
@testable import FocusTimer

/// The Break alert's Done action. Each `makeTimer()` after the first stands for a new process.
@MainActor
struct TimerStoreNotificationDoneTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
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

    func expectDoneIsIgnored(
        _ timer: TimerStore,
        cycleID: UUID?,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let state = timer.state
        let writes = store.writtenKeys.count
        let calls = notifications.calls.count

        timer.doneFromNotification(cycleID: cycleID)

        #expect(timer.state == state, sourceLocation: sourceLocation)
        #expect(store.writtenKeys.count == writes, sourceLocation: sourceLocation)
        #expect(notifications.calls.count == calls, sourceLocation: sourceLocation)
    }

    // MARK: A valid Done

    @Test func matchingDoneEndsTheCycle() {
        let timer = makeCompleted()
        let calls = notifications.calls.count

        timer.doneFromNotification(cycleID: timer.state.cycleID)

        #expect(timer.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
        #expect(Array(notifications.calls.dropFirst(calls)) == [.cancelAll, .removeAllDelivered])
    }

    @Test func matchingDoneSavesTheDurationsLikeInAppDone() {
        let timer = makeCompleted()
        timer.configuration.durationASeconds = 90

        timer.doneFromNotification(cycleID: timer.state.cycleID)

        #expect(savedConfiguration()?.durationASeconds == 120)
    }

    @Test func matchingDoneAfterBreakEndedInTheBackgroundEndsTheCycle() {
        let timer = makeBreakRunning()
        let cycleID = timer.state.cycleID
        clock.advance(by: 600)

        timer.doneFromNotification(cycleID: cycleID)

        #expect(timer.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
    }

    @Test func matchingDoneAfterBreakEndedWhileClosedEndsTheCycle() {
        let cycleID = makeBreakRunning().state.cycleID
        clock.advance(by: 60)

        let launched = makeTimer()
        #expect(launched.state.phase == .completed)
        launched.doneFromNotification(cycleID: cycleID)

        #expect(launched.state == TimerStore.TimerState())
        #expect(makeTimer().state == TimerStore.TimerState())
    }

    // MARK: Stale and duplicate actions

    @Test func doneFromAnEarlierCycleIsIgnored() {
        let timer = makeCompleted()
        let oldCycle = timer.state.cycleID
        timer.done()
        _ = makeCompleted(on: timer)
        #expect(timer.state.cycleID != oldCycle)

        expectDoneIsIgnored(timer, cycleID: oldCycle)
    }

    @Test func doneFromAnEarlierCycleLeavesANewerExpiredBreakUnreconciled() {
        let timer = makeCompleted()
        let oldCycle = timer.state.cycleID
        timer.done()
        _ = makeBreakRunning(on: timer)
        clock.advance(by: 60)
        #expect(timer.state.phase == .runningB)

        expectDoneIsIgnored(timer, cycleID: oldCycle)
        #expect(notifications.pendingPhases.contains(.runningB))
    }

    @Test func doneFromAnEarlierCycleLeavesANewerBreakAfterABackwardClockJump() {
        let timer = makeCompleted()
        let oldCycle = timer.state.cycleID
        timer.done()
        _ = makeBreakRunning(on: timer)
        clock.advance(by: -3_600)

        expectDoneIsIgnored(timer, cycleID: oldCycle)
    }

    @Test(arguments: [nil, UUID()] as [UUID?])
    func doneWithoutOrWithUnknownIDLeavesAnExpiredBreakUnreconciled(_ cycleID: UUID?) {
        let timer = makeBreakRunning()
        clock.advance(by: 60)

        expectDoneIsIgnored(timer, cycleID: cycleID)
    }

    @Test(arguments: [nil, UUID()] as [UUID?])
    func doneWithoutOrWithUnknownIDIsIgnored(_ cycleID: UUID?) {
        expectDoneIsIgnored(makeCompleted(), cycleID: cycleID)
    }

    @Test func repeatedDoneIsIgnored() {
        let timer = makeCompleted()
        let cycleID = timer.state.cycleID
        timer.doneFromNotification(cycleID: cycleID)

        expectDoneIsIgnored(timer, cycleID: cycleID)
    }

    @Test func doneAfterALaunchResetIsIgnored() {
        let cycleID = makeCompleted().state.cycleID

        let launched = makeTimer()
        #expect(launched.state == TimerStore.TimerState())

        expectDoneIsIgnored(launched, cycleID: cycleID)
    }

    // MARK: Done before the cycle is complete

    @Test func doneIsIgnoredOutsideCompleted() {
        let timer = makeTimer()
        expectDoneIsIgnored(timer, cycleID: nil)

        timer.startFocus()
        expectDoneIsIgnored(timer, cycleID: timer.state.cycleID)
        timer.pauseOrResume()
        expectDoneIsIgnored(timer, cycleID: timer.state.cycleID)
        timer.pauseOrResume()

        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .waitingForAConfirm)
        expectDoneIsIgnored(timer, cycleID: timer.state.cycleID)

        timer.startBreak()
        expectDoneIsIgnored(timer, cycleID: timer.state.cycleID)
        timer.pauseOrResume()
        expectDoneIsIgnored(timer, cycleID: timer.state.cycleID)
    }
}
