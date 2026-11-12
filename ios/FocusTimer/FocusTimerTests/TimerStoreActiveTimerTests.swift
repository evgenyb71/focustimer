import Foundation
import Testing
@testable import FocusTimer

/// The active-timer presentation: which timer is running or paused, and what VoiceOver reads for it.
@MainActor
struct TimerStoreActiveTimerTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
    }

    func makeWaiting() -> TimerStore {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        return timer
    }

    // MARK: Which timer is active

    @Test func idleHasNoActiveTimer() {
        let timer = makeTimer()

        #expect(timer.activeTimer == nil)
        #expect(timer.activeTimerAccessibilityLabel == nil)
        #expect(timer.statusTitle == "Ready")
    }

    @Test func focusRunningIsTheActiveFocus() {
        let timer = makeTimer()

        timer.startFocus()

        #expect(timer.activeTimer == .init(kind: .focus, paused: false))
        #expect(timer.activeTimer?.name == "Focus")
        #expect(timer.statusTitle == "Running")
        #expect(timer.endState == nil)
    }

    @Test func pauseAndResumeFollowTheActiveFocus() {
        let timer = makeTimer()
        timer.startFocus()

        timer.pauseOrResume()
        #expect(timer.activeTimer == .init(kind: .focus, paused: true))
        #expect(timer.statusTitle == "Paused")

        timer.pauseOrResume()
        #expect(timer.activeTimer == .init(kind: .focus, paused: false))
        #expect(timer.statusTitle == "Running")
    }

    @Test func waitingForBreakKeepsTheFocusEndState() {
        let timer = makeWaiting()

        #expect(timer.activeTimer == nil)
        #expect(timer.activeTimerAccessibilityLabel == nil)
        #expect(timer.endState == .focusComplete)
    }

    @Test func breakRunningAndPausedAreTheActiveBreak() {
        let timer = makeWaiting()

        timer.startOrConfirmBreak()
        #expect(timer.activeTimer == .init(kind: .breakTime, paused: false))
        #expect(timer.activeTimer?.name == "Break")

        timer.pauseOrResume()
        #expect(timer.activeTimer == .init(kind: .breakTime, paused: true))
    }

    @Test func completedKeepsTheBreakEndState() {
        let timer = makeWaiting()
        timer.startOrConfirmBreak()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()

        #expect(timer.activeTimer == nil)
        #expect(timer.endState == .breakComplete)
    }

    @Test func cancelEndsTheActiveTimer() {
        let timer = makeTimer()
        timer.startFocus()

        timer.cancel()

        #expect(timer.activeTimer == nil)
    }

    // MARK: Spoken label

    @Test func theLabelNamesTheRunningFocusAndItsTime() {
        let timer = makeTimer()
        timer.configuration.durationASeconds = 13 * 60
        timer.startFocus()
        clock.advance(by: 30)
        timer.reconcileWithCurrentTime()

        #expect(timer.activeTimerAccessibilityLabel == "Focus, running, 12 minutes 30 seconds remaining")
    }

    @Test func theLabelNamesAPausedBreak() {
        let timer = makeWaiting()
        timer.startOrConfirmBreak()
        clock.advance(by: 59)
        timer.reconcileWithCurrentTime()
        timer.pauseOrResume()

        #expect(timer.activeTimerAccessibilityLabel == "Break, paused, 1 second remaining")
    }

    @Test func theLabelFollowsTheCountdown() {
        let timer = makeTimer()
        timer.startFocus()
        #expect(timer.activeTimerAccessibilityLabel == "Focus, running, 1 minute remaining")

        clock.advance(by: 15)
        timer.reconcileWithCurrentTime()

        #expect(timer.activeTimerAccessibilityLabel == "Focus, running, 45 seconds remaining")
    }

    @Test(arguments: [
        (0, "0 seconds"),
        (1, "1 second"),
        (59, "59 seconds"),
        (60, "1 minute"),
        (61, "1 minute 1 second"),
        (750, "12 minutes 30 seconds"),
        (240 * 60, "240 minutes"),
        (-5, "0 seconds"),
    ])
    func spokenDuration(seconds: Int, expected: String) {
        #expect(TimerStore.spokenDuration(seconds) == expected)
    }
}
