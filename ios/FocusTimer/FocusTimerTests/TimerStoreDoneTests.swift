import Foundation
import Testing
@testable import FocusTimer

@MainActor
struct TimerStoreDoneTests {
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

    func expectDoneChangesNothing(_ timer: TimerStore, sourceLocation: SourceLocation = #_sourceLocation) {
        let state = timer.state
        let configuration = timer.configuration
        let writes = store.writtenKeys.count
        let calls = notifications.calls.count

        timer.done()

        #expect(timer.state == state, sourceLocation: sourceLocation)
        #expect(timer.configuration == configuration, sourceLocation: sourceLocation)
        #expect(store.writtenKeys.count == writes, sourceLocation: sourceLocation)
        #expect(notifications.calls.count == calls, sourceLocation: sourceLocation)
    }

    // MARK: Done from completed

    @Test func doneReturnsToIdleAndSavesIt() {
        let timer = makeCompleted()

        timer.done()

        #expect(timer.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
        #expect(timer.endState == nil)
        #expect(timer.displayedSeconds == nil)
    }

    @Test func doneClearsACorrectionNotice() {
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

        timer.done()

        #expect(timer.statusMessage != TimerStore.repairNotice)
    }

    @Test func doneRemovesPendingAndDeliveredAlerts() {
        let timer = makeCompleted()
        let calls = notifications.calls.count

        timer.done()

        #expect(Array(notifications.calls.dropFirst(calls)) == [.cancelAll, .removeAllDelivered])
    }

    // MARK: Configuration

    @Test func doneKeepsTheDurations() {
        let timer = makeCompleted()
        let configuration = timer.configuration

        timer.done()

        #expect(timer.configuration == configuration)
        #expect(savedConfiguration() == configuration)
    }

    @Test func doneSavesEditedDurationsSoARelaunchLoadsThem() {
        let timer = makeCompleted()
        timer.configuration.durationASeconds = 300
        timer.configuration.durationBSeconds = 600

        timer.done()

        let relaunched = makeTimer()
        #expect(relaunched.configuration == TimerStore.Configuration(durationASeconds: 300, durationBSeconds: 600))
    }

    @Test func doneRoundsAndClampsEditedDurations() {
        let timer = makeCompleted()
        timer.configuration.durationASeconds = 90
        timer.configuration.durationBSeconds = 999_999

        timer.done()

        let expected = TimerStore.Configuration(durationASeconds: 120, durationBSeconds: 120 * 60)
        #expect(timer.configuration == expected)
        #expect(savedConfiguration() == expected)
    }

    // MARK: Done elsewhere

    @Test func repeatedDoneChangesNothing() {
        let timer = makeCompleted()
        timer.done()

        expectDoneChangesNothing(timer)
    }

    @Test func doneChangesNothingOutsideCompleted() {
        let timer = makeTimer()
        expectDoneChangesNothing(timer)

        timer.startFocus()
        expectDoneChangesNothing(timer)
        timer.pauseOrResume()
        expectDoneChangesNothing(timer)
        timer.pauseOrResume()

        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .waitingForAConfirm)
        expectDoneChangesNothing(timer)

        timer.startBreak()
        expectDoneChangesNothing(timer)
        timer.pauseOrResume()
        expectDoneChangesNothing(timer)
    }

    @Test func doneIsOfferedOnlyInCompleted() {
        let timer = makeTimer()
        #expect(!timer.canFinish)
        #expect(timer.canCancel)

        timer.startFocus()
        #expect(!timer.canFinish)
        #expect(timer.canCancel)

        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        #expect(!timer.canFinish)
        #expect(timer.canCancel)

        timer.startBreak()
        #expect(!timer.canFinish)
        #expect(timer.canCancel)

        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        #expect(timer.canFinish)
        #expect(!timer.canCancel)

        timer.done()
        #expect(!timer.canFinish)
        #expect(timer.canCancel)
    }

    // MARK: Relaunch

    @Test func doneWorksAfterBreakExpiredWhileClosed() {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        timer.startBreak()
        clock.advance(by: 60)

        let relaunched = makeTimer()
        #expect(relaunched.state.phase == .completed)
        relaunched.done()

        #expect(relaunched.state == TimerStore.TimerState())
        #expect(savedState() == TimerStore.TimerState())
    }

    @Test func relaunchAfterDoneStaysIdle() {
        let timer = makeCompleted()
        timer.done()

        let relaunched = makeTimer()

        #expect(relaunched.state == TimerStore.TimerState())
        #expect(relaunched.endState == nil)
        #expect(relaunched.statusMessage != TimerStore.repairNotice)
    }

    // MARK: The next cycle

    @Test func aNewFocusAfterDoneStillWaitsForBreakConfirmation() {
        let timer = makeCompleted()
        let finishedCycle = notifications.scheduledCycleIDs.last ?? nil
        timer.done()

        timer.startFocus()
        #expect(timer.state.phase == .runningA)
        #expect(timer.state.cycleID != nil)
        #expect(timer.state.cycleID != finishedCycle)

        clock.advance(by: 3_600)
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .waitingForAConfirm)
    }
}
