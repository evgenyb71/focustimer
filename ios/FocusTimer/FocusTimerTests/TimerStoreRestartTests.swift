import Foundation
import Testing
@testable import FocusTimer

/// Restart is the primary button in completed, so these tests call what the button calls.
@MainActor
struct TimerStoreRestartTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
    }

    func makeCompleted() -> TimerStore {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        timer.startBreak()
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

    // MARK: Restart from completed

    @Test func restartRunsFocusWithANewCycle() throws {
        let timer = makeCompleted()
        let finishedCycle = try #require(timer.state.cycleID)

        timer.startOrConfirmBreak()

        #expect(timer.state.phase == .runningA)
        #expect(timer.state.endTimestamp == clock.now.addingTimeInterval(60))
        #expect(!timer.state.paused)
        #expect(timer.state.remainingSeconds == nil)
        let newCycle = try #require(timer.state.cycleID)
        #expect(newCycle != finishedCycle)
        #expect(savedState() == timer.state)
    }

    @Test func restartClearsACorrectionNotice() {
        // A Break that ended while closed reaches completed; the unreadable configuration adds the notice.
        let saved = TimerStore.TimerState(phase: .runningB, endTimestamp: clock.now.addingTimeInterval(-1), cycleID: UUID())
        if let state = try? JSONEncoder().encode(saved),
           let version = try? JSONEncoder().encode(TimerStore.currentSchemaVersion) {
            store.setData(state, forKey: "state")
            store.setData(Data("not json".utf8), forKey: "config")
            store.setData(version, forKey: "schemaVersion")
        }
        let timer = makeTimer()
        #expect(timer.state.phase == .completed)
        #expect(timer.statusMessage == TimerStore.repairNotice)

        timer.startOrConfirmBreak()

        #expect(timer.statusMessage != TimerStore.repairNotice)
    }

    // MARK: Durations

    @Test func restartUsesAndSavesEditedDurations() {
        let timer = makeCompleted()
        timer.configuration.durationASeconds = 300
        timer.configuration.durationBSeconds = 600

        timer.startOrConfirmBreak()

        #expect(timer.state.endTimestamp == clock.now.addingTimeInterval(300))
        let relaunched = makeTimer()
        #expect(relaunched.configuration == TimerStore.Configuration(durationASeconds: 300, durationBSeconds: 600))
    }

    @Test func restartRoundsAndClampsEditedDurations() {
        let timer = makeCompleted()
        timer.configuration.durationASeconds = 90
        timer.configuration.durationBSeconds = 999_999

        timer.startOrConfirmBreak()

        let expected = TimerStore.Configuration(durationASeconds: 120, durationBSeconds: 120 * 60)
        #expect(timer.configuration == expected)
        #expect(savedConfiguration() == expected)
        #expect(timer.state.endTimestamp == clock.now.addingTimeInterval(120))
    }

    // MARK: Alerts

    @Test func restartClearsEarlierAlertsThenSchedulesOneFocusAlert() {
        let timer = makeCompleted()
        let calls = notifications.calls.count
        let schedules = notifications.scheduledCycleIDs.count

        timer.startOrConfirmBreak()

        let now = clock.now
        #expect(Array(notifications.calls.dropFirst(calls)) == [
            .cancelAll,
            .removeAllDelivered,
            .schedule(phase: .runningA, deadline: now.addingTimeInterval(60), now: now),
        ])
        #expect(Array(notifications.scheduledCycleIDs.dropFirst(schedules)) == [timer.state.cycleID])
    }

    @Test func repeatedRestartKeepsTheRunningFocus() {
        let timer = makeCompleted()
        timer.startOrConfirmBreak()
        let state = timer.state
        let writes = store.writtenKeys.count
        let calls = notifications.calls.count
        clock.advance(by: 5)

        timer.startOrConfirmBreak()

        #expect(timer.state == state)
        #expect(store.writtenKeys.count == writes)
        #expect(notifications.calls.count == calls)
    }

    // MARK: Break confirmation

    @Test func theNewFocusStillWaitsForBreakConfirmation() {
        let timer = makeCompleted()
        timer.startOrConfirmBreak()

        clock.advance(by: 3_600)
        timer.reconcileWithCurrentTime()

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(timer.endState == .focusComplete)
        #expect(timer.primaryButtonTitle == "Start Break")
    }

    @Test func anAlertFromTheFinishedCycleCannotStartBreakInTheNewCycle() throws {
        let timer = makeCompleted()
        let finishedCycle = try #require(timer.state.cycleID)
        timer.startOrConfirmBreak()

        timer.startBreakFromNotification(cycleID: finishedCycle)
        #expect(timer.state.phase == .runningA)

        clock.advance(by: 60)
        timer.startBreakFromNotification(cycleID: finishedCycle)
        #expect(timer.state.phase == .waitingForAConfirm)

        timer.startBreakFromNotification(cycleID: timer.state.cycleID)
        #expect(timer.state.phase == .runningB)
    }

    // MARK: Relaunch

    @Test func restartWorksAfterBreakExpiredWhileClosed() throws {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        timer.startBreak()
        let finishedCycle = try #require(timer.state.cycleID)
        clock.advance(by: 60)

        let relaunched = makeTimer()
        #expect(relaunched.state.phase == .completed)
        #expect(relaunched.primaryButtonTitle == "Restart")
        relaunched.startOrConfirmBreak()

        #expect(relaunched.state.phase == .runningA)
        #expect(relaunched.state.endTimestamp == clock.now.addingTimeInterval(60))
        #expect(relaunched.state.cycleID != finishedCycle)
        #expect(savedState() == relaunched.state)
    }
}
