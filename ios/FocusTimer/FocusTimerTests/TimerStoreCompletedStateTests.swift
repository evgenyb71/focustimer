import Foundation
import Testing
@testable import FocusTimer

@MainActor
struct TimerStoreCompletedStateTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
    }

    func makeBreakRunning() -> TimerStore {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        timer.startBreak()
        return timer
    }

    func makeCompleted() -> TimerStore {
        let timer = makeBreakRunning()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        return timer
    }

    func savedState() -> TimerStore.TimerState? {
        store.values["state"].flatMap { try? JSONDecoder().decode(TimerStore.TimerState.self, from: $0) }
    }

    func seed(state: Data, version: Int = TimerStore.currentSchemaVersion) {
        store.setData(state, forKey: "state")
        if let data = try? JSONEncoder().encode(version) {
            store.setData(data, forKey: "schemaVersion")
        }
    }

    func encoded(_ state: TimerStore.TimerState) -> Data {
        (try? JSONEncoder().encode(state)) ?? Data()
    }

    // MARK: Entering completed

    @Test func breakExpiryEntersCompletedWithTheCycleID() {
        let timer = makeBreakRunning()
        let cycleID = timer.state.cycleID
        clock.advance(by: 60)

        timer.reconcileWithCurrentTime()

        let completed = TimerStore.TimerState(phase: .completed, cycleID: cycleID)
        #expect(timer.state == completed)
        #expect(savedState() == completed)
        #expect(timer.displayedSeconds == nil)
        #expect(timer.endState == .breakComplete)
    }

    @Test func completedIsEnteredOnce() {
        let timer = makeCompleted()
        let completed = timer.state
        let writes = store.writtenKeys.count
        let calls = notifications.calls.count

        clock.advance(by: 3_600)
        timer.reconcileWithCurrentTime()
        timer.reconcileWithCurrentTime()

        #expect(timer.state == completed)
        #expect(store.writtenKeys.count == writes)
        #expect(notifications.calls.count == calls)
    }

    @Test func activationAndLaunchEnterCompletedAfterAFinishedBreak() {
        let timer = makeBreakRunning()
        let cycleID = timer.state.cycleID
        clock.advance(by: 86_400)

        let relaunched = makeTimer()

        #expect(relaunched.state == TimerStore.TimerState(phase: .completed, cycleID: cycleID))

        let other = makeBreakRunning()
        clock.advance(by: 86_400)
        other.activate()
        #expect(other.state.phase == .completed)
    }

    @Test func pausedBreakWithoutTimeLeftIsRepairedToCompleted() {
        seed(state: encoded(TimerStore.TimerState(phase: .runningB, paused: true, remainingSeconds: 0, cycleID: UUID())))

        let timer = makeTimer()

        #expect(timer.state.phase == .completed)
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    // MARK: Relaunch and repair

    @Test func relaunchRestoresCompletedWithoutNotice() {
        _ = makeCompleted()
        let saved = store.values

        let relaunched = makeTimer()

        #expect(relaunched.state.phase == .completed)
        #expect(relaunched.state.endTimestamp == nil)
        #expect(relaunched.state.cycleID != nil)
        #expect(relaunched.endState == .breakComplete)
        #expect(relaunched.statusMessage != TimerStore.repairNotice)
        #expect(store.values == saved)
    }

    @Test func completedWithStrayTimingFieldsIsRepaired() {
        let cycleID = UUID()
        seed(state: encoded(TimerStore.TimerState(phase: .completed, endTimestamp: clock.now.addingTimeInterval(30), paused: true, remainingSeconds: 10, cycleID: cycleID)))

        let timer = makeTimer()

        #expect(timer.state == TimerStore.TimerState(phase: .completed, cycleID: cycleID))
        #expect(savedState() == timer.state)
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    @Test func completedWithoutACycleIDGetsOne() {
        seed(state: encoded(TimerStore.TimerState(phase: .completed)))

        let timer = makeTimer()

        #expect(timer.state.phase == .completed)
        #expect(timer.state.cycleID != nil)
        #expect(savedState() == timer.state)
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    // MARK: Schema version 3

    @Test func version2RecordsMigrateToVersion3Unchanged() {
        let state = encoded(TimerStore.TimerState(phase: .waitingForAConfirm, cycleID: UUID()))
        seed(state: state, version: 2)
        let mark = store.writtenKeys.count

        let timer = makeTimer()

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(store.values["state"] == state)
        #expect(Array(store.writtenKeys.dropFirst(mark)) == ["schemaVersion"])
        #expect(store.values["schemaVersion"] == (try? JSONEncoder().encode(3)))
        #expect(timer.statusMessage != TimerStore.repairNotice)
    }

    @Test func version2IdleStaysIdle() {
        seed(state: encoded(TimerStore.TimerState()), version: 2)

        let timer = makeTimer()

        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.endState == nil)
    }

    // MARK: Leaving completed

    @Test func startFocusFromCompletedStartsANewCycle() {
        let timer = makeCompleted()
        let oldCycle = timer.state.cycleID
        let mark = notifications.calls.count

        timer.startOrConfirmBreak()

        #expect(timer.state.phase == .runningA)
        #expect(timer.state.cycleID != nil)
        #expect(timer.state.cycleID != oldCycle)
        #expect(Array(notifications.calls.dropFirst(mark)).prefix(2) == [.cancelAll, .removeAllDelivered])
    }

    @Test func cancelFromCompletedReturnsToIdleAndRemovesAlerts() {
        let timer = makeCompleted()
        let mark = notifications.calls.count

        timer.cancel()

        #expect(timer.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
        #expect(Array(notifications.calls.dropFirst(mark)) == [.cancelAll, .removeAllDelivered])
    }

    @Test func durationsCanBeEditedInCompletedAndStartUsesThem() {
        let timer = makeCompleted()
        #expect(timer.canEditDurations)
        #expect(timer.canStart)
        #expect(!timer.canPause)

        timer.configuration = TimerStore.Configuration(durationASeconds: 300, durationBSeconds: 120)
        #expect(timer.state.phase == .completed)

        let start = clock.now
        timer.startFocus()
        #expect(timer.state.endTimestamp == start.addingTimeInterval(300))
    }

    @Test func pauseAndTheFocusActionDoNothingInCompleted() {
        let timer = makeCompleted()
        let completed = timer.state
        let mark = notifications.calls.count

        timer.pauseOrResume()
        timer.startBreakFromNotification(cycleID: completed.cycleID)

        #expect(timer.state == completed)
        #expect(notifications.calls.count == mark)
    }

    // MARK: Alerts

    @Test func breakCompletionCancelsOnlyThePendingBreakRequest() {
        let timer = makeBreakRunning()
        let mark = notifications.calls.count
        clock.advance(by: 60)

        timer.reconcileWithCurrentTime()

        #expect(Array(notifications.calls.dropFirst(mark)) == [.cancel(phase: .runningB)])
    }

    @Test func activationAndLaunchInCompletedKeepTheBreakAlert() {
        let timer = makeCompleted()
        let mark = notifications.calls.count

        timer.activate()
        _ = makeTimer()

        #expect(Array(notifications.calls.dropFirst(mark)) == [
            .removeDelivered(phase: .runningA),
            .removeDelivered(phase: .runningA),
        ])
    }
}
