import Foundation
import Testing
@testable import FocusTimer

@MainActor
struct TimerStoreEndStateTests {
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

    func makeBreakFinished() -> TimerStore {
        let timer = makeWaitingForBreak()
        timer.startBreak()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        return timer
    }

    // MARK: Which end state shows

    @Test func noEndStateWhileIdleOrRunning() {
        let timer = makeTimer()
        #expect(timer.endState == nil)
        #expect(timer.primaryButtonTitle == "Start")

        timer.startFocus()
        #expect(timer.endState == nil)
        timer.pauseOrResume()
        #expect(timer.endState == nil)
    }

    @Test func focusEndShowsWhileWaitingForBreak() {
        let timer = makeWaitingForBreak()

        #expect(timer.endState == .focusComplete)
        #expect(timer.endHeadline == "Focus complete")
        #expect(timer.statusMessage == "Take a break when you're ready.")
        #expect(timer.primaryButtonTitle == "Start Break")
    }

    @Test func breakRunningShowsNoEndState() {
        let timer = makeWaitingForBreak()
        timer.startBreak()

        #expect(timer.endState == nil)
    }

    @Test func breakEndShowsAfterBreakCompletes() {
        let timer = makeBreakFinished()

        #expect(timer.state.phase == .completed)
        #expect(timer.endState == .breakComplete)
        #expect(timer.endHeadline == "Cycle complete")
        #expect(timer.statusMessage == "Start another Focus when you're ready.")
        #expect(timer.primaryButtonTitle == "Start Focus")
    }

    @Test func breakEndShowsWhenActivationReconcilesAFinishedBreak() {
        let timer = makeWaitingForBreak()
        timer.startBreak()
        clock.advance(by: 3_600)

        timer.activate()

        #expect(timer.endState == .breakComplete)
    }

    @Test func breakEndShowsWhenLaunchReconcilesAFinishedBreak() {
        let timer = makeWaitingForBreak()
        timer.startBreak()
        clock.advance(by: 3_600)

        let relaunched = makeTimer()

        #expect(relaunched.state.phase == .completed)
        #expect(relaunched.endState == .breakComplete)
    }

    @Test func noticeStillReplacesTheNextStepLine() {
        store.setData(Data("not json".utf8), forKey: "state")
        if let data = try? JSONEncoder().encode(TimerStore.currentSchemaVersion) {
            store.setData(data, forKey: "schemaVersion")
        }

        let timer = makeTimer()

        #expect(timer.endState == nil)
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    // MARK: Leaving the Break end (completed since I13)

    @Test func startClearsTheBreakEnd() {
        let timer = makeBreakFinished()

        timer.startOrConfirmBreak()

        #expect(timer.state.phase == .runningA)
        #expect(timer.endState == nil)
    }

    @Test func cancelClearsTheBreakEnd() {
        let timer = makeBreakFinished()

        timer.cancel()

        #expect(timer.endState == nil)
    }

    @Test func durationEditKeepsTheBreakEnd() {
        let timer = makeBreakFinished()

        timer.configuration.durationASeconds = 120

        #expect(timer.state.phase == .completed)
        #expect(timer.endState == .breakComplete)
        #expect(timer.primaryButtonTitle == "Start Focus")
    }

    @Test func relaunchKeepsTheBreakEnd() {
        _ = makeBreakFinished()

        let relaunched = makeTimer()

        #expect(relaunched.endState == .breakComplete)
        #expect(relaunched.statusMessage == "Start another Focus when you're ready.")
    }
}
