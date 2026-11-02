import Foundation
import Testing
@testable import FocusTimer

enum ClockJumpPhase: CaseIterable, Sendable {
    case focus, breakTime
}

@MainActor
struct TimerStoreClockEdgeTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    let focusSeconds = 25 * 60
    let breakSeconds = 5 * 60

    func makeTimer() -> TimerStore {
        let timer = TimerStore(clock: clock, store: store, notifications: notifications)
        timer.configuration = TimerStore.Configuration(durationASeconds: focusSeconds, durationBSeconds: breakSeconds)
        return timer
    }

    func relaunch() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
    }

    func makeWaitingForBreak() -> TimerStore {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: TimeInterval(focusSeconds))
        timer.reconcileWithCurrentTime()
        return timer
    }

    func makeRunning(_ phase: ClockJumpPhase) -> TimerStore {
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

    func duration(_ phase: ClockJumpPhase) -> Int {
        phase == .focus ? focusSeconds : breakSeconds
    }

    func completed(_ phase: ClockJumpPhase) -> TimerStore.TimerState {
        phase == .focus ? TimerStore.TimerState(phase: .waitingForAConfirm) : TimerStore.TimerState(phase: .completed)
    }

    func savedState() -> TimerStore.TimerState? {
        store.values["state"].flatMap { try? JSONDecoder().decode(TimerStore.TimerState.self, from: $0) }
    }

    func seed(state: TimerStore.TimerState) {
        if let data = try? JSONEncoder().encode(TimerStore.Configuration(durationASeconds: focusSeconds, durationBSeconds: breakSeconds)) {
            store.setData(data, forKey: "config")
        }
        if let data = try? JSONEncoder().encode(state) {
            store.setData(data, forKey: "state")
        }
        if let data = try? JSONEncoder().encode(TimerStore.currentSchemaVersion) {
            store.setData(data, forKey: "schemaVersion")
        }
    }

    // MARK: Pause at or after expiry

    @Test(arguments: ClockJumpPhase.allCases, [0, 1, 3_600] as [TimeInterval])
    func pauseAtOrAfterExpiryCompletesThePhase(_ phase: ClockJumpPhase, _ secondsLate: TimeInterval) {
        let timer = makeRunning(phase)
        clock.advance(by: TimeInterval(duration(phase)) + secondsLate)
        let mark = notifications.pendingCalls.count

        timer.pauseOrResume()

        #expect(timer.state.ignoringCycle == completed(phase))
        #expect(savedState()?.ignoringCycle == completed(phase))
        #expect(!timer.state.paused)
        // Break completion cancels its pending request (I11); Focus completion makes no call.
        let expected: [RecordingNotificationScheduler.Call] = phase == .focus ? [] : [.cancel(phase: .runningB)]
        #expect(Array(notifications.pendingCalls.dropFirst(mark)) == expected)
    }

    @Test func pauseJustBeforeExpiryKeepsOneSecond() {
        let timer = makeRunning(.focus)
        clock.advance(by: TimeInterval(focusSeconds) - 0.4)

        timer.pauseOrResume()

        #expect(timer.state.paused)
        #expect(timer.state.remainingSeconds == 1)
    }

    // MARK: Backward clock jump

    @Test(arguments: ClockJumpPhase.allCases)
    func backwardJumpCapsTheDeadlineAtTheFullDuration(_ phase: ClockJumpPhase) {
        let timer = makeRunning(phase)
        let cycleID = timer.state.cycleID
        clock.advance(by: -900)
        let mark = notifications.calls.count
        let now = clock.now

        timer.reconcileWithCurrentTime()

        let capped = now.addingTimeInterval(TimeInterval(duration(phase)))
        #expect(timer.state.endTimestamp == capped)
        #expect(savedState()?.endTimestamp == capped)
        #expect(timer.displayedSeconds == duration(phase))
        #expect(timer.statusMessage != TimerStore.repairNotice)
        #expect(Array(notifications.calls.dropFirst(mark)) == [
            .schedule(phase: phase == .focus ? .runningA : .runningB, deadline: capped, now: now),
        ])
        #expect(notifications.scheduledCycleIDs.last == cycleID)

        timer.reconcileWithCurrentTime()
        #expect(notifications.calls.count == mark + 1)
    }

    @Test func clockJumpWithinTheDurationChangesNothing() {
        let timer = makeRunning(.focus)
        clock.advance(by: 600)
        timer.reconcileWithCurrentTime()
        let deadline = timer.state.endTimestamp
        let mark = notifications.calls.count
        clock.advance(by: -300)

        timer.reconcileWithCurrentTime()

        #expect(timer.state.endTimestamp == deadline)
        #expect(notifications.calls.count == mark)
    }

    @Test func launchCapsASavedDeadlineThatIsTooFarAwayWithoutNotice() {
        let deadline = clock.now.addingTimeInterval(TimeInterval(focusSeconds + 600))
        seed(state: TimerStore.TimerState(phase: .runningA, endTimestamp: deadline, cycleID: UUID()))

        let timer = relaunch()

        let capped = clock.now.addingTimeInterval(TimeInterval(focusSeconds))
        #expect(timer.state.endTimestamp == capped)
        #expect(savedState()?.endTimestamp == capped)
        #expect(timer.statusMessage != TimerStore.repairNotice)
    }

    @Test func launchWithCorruptConfigurationCapsALongerRunningPhaseToTheDefault() {
        // Documented limitation: the cap uses the current configuration, so a running phase longer
        // than the default is shortened when the saved configuration was unreadable (I09).
        let deadline = clock.now.addingTimeInterval(600)
        store.setData(Data("not json".utf8), forKey: "config")
        if let data = try? JSONEncoder().encode(TimerStore.TimerState(phase: .runningA, endTimestamp: deadline, cycleID: UUID())) {
            store.setData(data, forKey: "state")
        }
        if let data = try? JSONEncoder().encode(TimerStore.currentSchemaVersion) {
            store.setData(data, forKey: "schemaVersion")
        }

        let timer = relaunch()

        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state.endTimestamp == clock.now.addingTimeInterval(60))
    }

    // MARK: Extreme saved deadlines (Codex review)

    func storePhase(_ phase: ClockJumpPhase) -> TimerStore.Phase {
        phase == .focus ? .runningA : .runningB
    }

    @Test(arguments: ClockJumpPhase.allCases)
    func launchWithAnExtremeFutureDeadlineCapsItInsteadOfCrashing(_ phase: ClockJumpPhase) {
        let cycleID = UUID()
        // Far outside the Int range in seconds, but a valid saved Date.
        let extreme = Date(timeIntervalSinceReferenceDate: 1e20)
        seed(state: TimerStore.TimerState(phase: storePhase(phase), endTimestamp: extreme, cycleID: cycleID))

        let timer = relaunch()

        let capped = clock.now.addingTimeInterval(TimeInterval(duration(phase)))
        #expect(timer.state == TimerStore.TimerState(phase: storePhase(phase), endTimestamp: capped, cycleID: cycleID))
        #expect(savedState() == timer.state)
        #expect(timer.displayedSeconds == duration(phase))
        #expect(timer.statusMessage != TimerStore.repairNotice)
        // The capped reschedule is the only pending-request call at launch.
        #expect(notifications.pendingCalls == [.schedule(phase: storePhase(phase), deadline: capped, now: clock.now)])
        #expect(notifications.scheduledCycleIDs == [cycleID])

        clock.advance(by: 10)
        timer.pauseOrResume()
        #expect(timer.state.paused)
        #expect(timer.state.remainingSeconds == duration(phase) - 10)
    }

    @Test(arguments: ClockJumpPhase.allCases)
    func launchWithAnExtremePastDeadlineCompletesInsteadOfCrashing(_ phase: ClockJumpPhase) {
        let cycleID = UUID()
        let extreme = Date(timeIntervalSinceReferenceDate: -1e20)
        seed(state: TimerStore.TimerState(phase: storePhase(phase), endTimestamp: extreme, cycleID: cycleID))

        let timer = relaunch()

        let expected = phase == .focus
            ? TimerStore.TimerState(phase: .waitingForAConfirm, cycleID: cycleID)
            : TimerStore.TimerState(phase: .completed, cycleID: cycleID)
        #expect(timer.state == expected)
        #expect(savedState() == expected)
        #expect(timer.displayedSeconds == (phase == .focus ? 0 : nil))
        // No Break is started or scheduled; Break completion only cancels its own pending request.
        #expect(notifications.pendingCalls == (phase == .focus ? [] : [.cancel(phase: .runningB)]))
    }


    @Test(arguments: ClockJumpPhase.allCases)
    func launchClampsAnOverLongPausedTimeWithNotice(_ phase: ClockJumpPhase) {
        let storePhase: TimerStore.Phase = phase == .focus ? .runningA : .runningB
        seed(state: TimerStore.TimerState(phase: storePhase, paused: true, remainingSeconds: duration(phase) + 1, cycleID: UUID()))

        let timer = relaunch()

        #expect(timer.state.remainingSeconds == duration(phase))
        #expect(savedState()?.remainingSeconds == duration(phase))
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    @Test func launchKeepsAPausedTimeOfExactlyTheDuration() {
        seed(state: TimerStore.TimerState(phase: .runningA, paused: true, remainingSeconds: focusSeconds, cycleID: UUID()))

        let timer = relaunch()

        #expect(timer.state.remainingSeconds == focusSeconds)
        #expect(timer.statusMessage != TimerStore.repairNotice)
    }

    // MARK: Forward clock jump

    @Test func forwardJumpPastFocusWaitsForConfirmation() {
        let timer = makeRunning(.focus)
        clock.advance(by: 86_400)

        timer.reconcileWithCurrentTime()

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(phase: .waitingForAConfirm))
        #expect(notifications.scheduledCycleIDs.count == 1)
    }

    @Test func forwardJumpPastBreakCompletesTheCycle() {
        let timer = makeRunning(.breakTime)
        clock.advance(by: 86_400)

        timer.reconcileWithCurrentTime()

        #expect(timer.state.ignoringCycle == TimerStore.TimerState(phase: .completed))
    }

    // MARK: Duplicate callbacks and delayed activation

    @Test func repeatedActivationAfterALongDelayCompletesOnce() {
        let timer = makeRunning(.focus)
        clock.advance(by: 7 * 86_400)

        timer.activate()
        let afterFirst = timer.state
        let mark = notifications.calls.count
        timer.activate()
        timer.reconcileWithCurrentTime()

        #expect(afterFirst.phase == .waitingForAConfirm)
        #expect(timer.state == afterFirst)
        // Only the activation cleanup repeats; no schedule or cancel.
        #expect(Array(notifications.calls.dropFirst(mark)) == [.removeDelivered(phase: .runningB)])
        #expect(notifications.pendingCalls.filter { if case .schedule = $0 { true } else { false } }.count == 1)
    }

    @Test func notificationActionAfterAForwardJumpStartsBreakOnce() {
        let timer = makeRunning(.focus)
        let cycleID = timer.state.cycleID
        clock.advance(by: 86_400)

        timer.startBreakFromNotification(cycleID: cycleID)
        timer.startBreakFromNotification(cycleID: cycleID)

        #expect(timer.state.phase == .runningB)
        #expect(notifications.scheduledCycleIDs.count == 2)
    }
}
