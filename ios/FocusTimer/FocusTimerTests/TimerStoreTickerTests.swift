import Foundation
import Testing
@testable import FocusTimer

/// The one-second ticker and the reset shared by Cancel and Done. The ticker tests turn automatic ticking on.
@MainActor
struct TimerStoreTickerTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer(ticksAutomatically: Bool = false) -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications, ticksAutomatically: ticksAutomatically)
    }

    // MARK: Ticker

    @Test func releasingTheStoreInvalidatesItsTicker() async throws {
        var timer: TimerStore? = makeTimer(ticksAutomatically: true)
        // The permission read holds the store until it finishes.
        await timer?.alertPermissionCheck?.value
        weak let released = timer
        let ticker = try #require(timer?.ticker)
        #expect(ticker.isValid)

        timer = nil

        let stillValid = ticker.isValid
        #expect(released == nil)
        #expect(stillValid == false)
    }

    @Test func tickerIsOnUnlessTurnedOff() {
        #expect(TimerStore(clock: clock, store: store, notifications: notifications).ticker?.isValid == true)
        #expect(makeTimer().ticker == nil)
    }

    @Test func tickUpdatesTheCountdown() throws {
        let timer = makeTimer(ticksAutomatically: true)
        timer.startFocus()
        clock.advance(by: 1)

        try #require(timer.ticker).fire()

        #expect(timer.displayedSeconds == 59)
        #expect(timer.state.phase == .runningA)
    }

    @Test func tickCompletesAnExpiredPhase() throws {
        let timer = makeTimer(ticksAutomatically: true)
        timer.startFocus()
        clock.advance(by: 60)

        try #require(timer.ticker).fire()
        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(timer.displayedSeconds == 0)

        timer.startBreak()
        clock.advance(by: 60)

        try #require(timer.ticker).fire()
        #expect(timer.state.phase == .completed)
        #expect(timer.displayedSeconds == nil)
    }

    // MARK: Shared reset

    func completedTimer() -> TimerStore {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        timer.startBreak()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        return timer
    }

    @Test func cancelResetsWithoutSavingTheConfiguration() {
        let timer = makeTimer()
        timer.startFocus()
        let configuration = timer.configuration
        let callMark = notifications.calls.count
        let writeMark = store.writtenKeys.count

        timer.cancel()

        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.displayedSeconds == nil)
        #expect(timer.configuration == configuration)
        #expect(Array(notifications.calls[callMark...]) == [.cancelAll, .removeAllDelivered])
        #expect(Array(store.writtenKeys[writeMark...]) == ["state"])
    }

    @Test func doneSavesTheConfigurationThenResets() {
        let timer = completedTimer()
        timer.configuration.durationASeconds = 130
        let callMark = notifications.calls.count
        let writeMark = store.writtenKeys.count

        timer.done()

        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.displayedSeconds == nil)
        #expect(timer.configuration.durationASeconds == 120)
        #expect(Array(notifications.calls[callMark...]) == [.cancelAll, .removeAllDelivered])
        #expect(Array(store.writtenKeys[writeMark...]) == ["config", "state"])
    }

    @Test func cancelStillResetsFromCompleted() {
        let timer = completedTimer()

        timer.cancel()

        #expect(timer.state == TimerStore.TimerState())
    }
}
