import Foundation
import Testing
@testable import FocusTimer

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
        // The completed cycle keeps its ID (I13); only Cancel or a new Focus ends it.
        #expect(timer.state == TimerStore.TimerState(phase: .completed, cycleID: cycleID))
        #expect(savedState() == timer.state)
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
        let deadline = clock.now.addingTimeInterval(30)
        let state: TimerStore.TimerState = switch fixture {
        case .idle: TimerStore.TimerState()
        case .runningFocus: TimerStore.TimerState(phase: .runningA, endTimestamp: deadline)
        case .runningBreak: TimerStore.TimerState(phase: .runningB, endTimestamp: deadline)
        case .pausedFocus: TimerStore.TimerState(phase: .runningA, paused: true, remainingSeconds: 45)
        case .pausedBreak: TimerStore.TimerState(phase: .runningB, paused: true, remainingSeconds: 30)
        case .waitingForBreak: TimerStore.TimerState(phase: .waitingForAConfirm)
        }
        seed(state: encoded(state), version: 1)

        let timer = makeTimer()

        #expect(timer.state.ignoringCycle == state)
        #expect(timer.state.cycleID != nil)
        #expect(savedState() == timer.state)
        #expect(store.values["schemaVersion"] == (try? JSONEncoder().encode(TimerStore.currentSchemaVersion)))
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
        let deadline = clock.now.addingTimeInterval(30)
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
