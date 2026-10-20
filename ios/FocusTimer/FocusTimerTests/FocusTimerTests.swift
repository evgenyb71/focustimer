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
