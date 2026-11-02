import Foundation
import Testing
@testable import FocusTimer

enum CleanupPhase: CaseIterable, Sendable {
    case idle, runningFocus, pausedFocus, waiting, runningBreak, pausedBreak
}

@MainActor
struct TimerStoreAlertCleanupTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer() -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications)
    }

    /// Removals of delivered alerts made after this point.
    func deliveredCalls(after mark: Int) -> [RecordingNotificationScheduler.Call] {
        Array(notifications.calls.dropFirst(mark)).filter { notifications.deliveredCalls.contains($0) }
    }

    func makeWaitingForBreak() -> TimerStore {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        return timer
    }

    // MARK: Events

    @Test func focusStartRemovesAllDeliveredAlerts() {
        let timer = makeTimer()
        let mark = notifications.calls.count

        timer.startFocus()

        #expect(deliveredCalls(after: mark) == [.removeAllDelivered])
    }

    @Test func focusStartAfterUnsupportedVersionCancelsAnOldPendingBreakRequest() {
        // A Break request scheduled by an earlier run is still pending when launch ignores the saved records.
        notifications.scheduleCompletion(for: .runningB, at: clock.now.addingTimeInterval(300), now: clock.now, cycleID: UUID())
        if let version = try? JSONEncoder().encode(TimerStore.currentSchemaVersion + 1) {
            store.setData(version, forKey: "schemaVersion")
        }
        let timer = makeTimer()
        #expect(timer.state == TimerStore.TimerState())
        #expect(notifications.pendingPhases == [.runningB])
        let mark = notifications.calls.count

        timer.startFocus()

        let calls = Array(notifications.calls.dropFirst(mark))
        let cancelIndex = calls.firstIndex(of: .cancelAll)
        let scheduleIndex = calls.firstIndex { if case .schedule = $0 { true } else { false } }
        #expect(cancelIndex != nil)
        #expect(scheduleIndex != nil)
        if let cancelIndex, let scheduleIndex {
            #expect(cancelIndex < scheduleIndex)
        }
        #expect(notifications.pendingPhases == [.runningA])
    }

    @Test func breakStartInTheAppRemovesTheDeliveredFocusAlert() {
        let timer = makeWaitingForBreak()
        let mark = notifications.calls.count

        timer.startOrConfirmBreak()

        #expect(timer.state.phase == .runningB)
        #expect(deliveredCalls(after: mark) == [.removeDelivered(phase: .runningA)])
    }

    @Test func breakStartFromAMatchingActionRemovesTheDeliveredFocusAlert() {
        let timer = makeWaitingForBreak()
        let mark = notifications.calls.count

        timer.startBreakFromNotification(cycleID: timer.state.cycleID)

        #expect(timer.state.phase == .runningB)
        #expect(deliveredCalls(after: mark) == [.removeDelivered(phase: .runningA)])
    }

    @Test(arguments: [nil, UUID()] as [UUID?])
    func ignoredActionRemovesNothing(_ cycleID: UUID?) {
        let timer = makeWaitingForBreak()
        let mark = notifications.calls.count

        timer.startBreakFromNotification(cycleID: cycleID)

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(notifications.calls.count == mark)
    }

    @Test func duplicateActionAfterBreakStartedRemovesNothing() {
        let timer = makeWaitingForBreak()
        let cycleID = timer.state.cycleID
        timer.startBreakFromNotification(cycleID: cycleID)
        let mark = notifications.calls.count

        timer.startBreakFromNotification(cycleID: cycleID)

        #expect(notifications.calls.count == mark)
    }

    @Test func focusCompletionKeepsTheCurrentAlert() {
        let timer = makeTimer()
        timer.startFocus()
        let mark = notifications.calls.count
        clock.advance(by: 60)

        timer.reconcileWithCurrentTime()

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(notifications.calls.count == mark)
    }

    @Test func breakCompletionRemovesOnlyThePendingBreakRequest() {
        let timer = makeWaitingForBreak()
        timer.startBreak()
        let mark = notifications.calls.count
        clock.advance(by: 60)

        timer.reconcileWithCurrentTime()

        #expect(timer.state.phase == .completed)
        #expect(Array(notifications.calls.dropFirst(mark)) == [.cancel(phase: .runningB)])
    }

    @Test func cancelRemovesAllPendingAndDeliveredAlerts() {
        let timer = makeWaitingForBreak()
        let mark = notifications.calls.count

        timer.cancel()

        #expect(Array(notifications.calls.dropFirst(mark)) == [.cancelAll, .removeAllDelivered])
    }

    @Test func pauseAndResumeRemoveNoDeliveredAlerts() {
        let timer = makeTimer()
        timer.startFocus()
        let mark = notifications.calls.count

        timer.pauseOrResume()
        timer.pauseOrResume()

        #expect(deliveredCalls(after: mark).isEmpty)
    }

    @Test func tickerReconcileRemovesNoDeliveredAlerts() {
        let timer = makeTimer()
        timer.startFocus()
        let mark = notifications.calls.count

        for _ in 0..<3 {
            clock.advance(by: 1)
            timer.reconcileWithCurrentTime()
        }

        #expect(notifications.calls.count == mark)
    }

    // MARK: Launch and activation

    func reach(_ phase: CleanupPhase) -> TimerStore {
        let timer = makeTimer()
        switch phase {
        case .idle:
            break
        case .runningFocus:
            timer.startFocus()
        case .pausedFocus:
            timer.startFocus()
            timer.pauseOrResume()
        case .waiting:
            return makeWaitingForBreak()
        case .runningBreak, .pausedBreak:
            let waiting = makeWaitingForBreak()
            waiting.startBreak()
            if phase == .pausedBreak {
                waiting.pauseOrResume()
            }
            return waiting
        }
        return timer
    }

    func expectedCleanup(_ phase: CleanupPhase) -> [RecordingNotificationScheduler.Call] {
        switch phase {
        case .idle, .runningFocus, .pausedFocus:
            [.removeDelivered(phase: .runningA), .removeDelivered(phase: .runningB)]
        case .waiting:
            [.removeDelivered(phase: .runningB)]
        case .runningBreak, .pausedBreak:
            [.removeDelivered(phase: .runningA)]
        }
    }

    @Test(arguments: CleanupPhase.allCases)
    func activationRemovesAlertsThatDoNotMatchThePhase(_ phase: CleanupPhase) {
        let timer = reach(phase)
        let mark = notifications.calls.count

        timer.activate()

        #expect(Array(notifications.calls.dropFirst(mark)) == expectedCleanup(phase))
    }

    @Test(arguments: CleanupPhase.allCases)
    func launchRemovesAlertsThatDoNotMatchThePhase(_ phase: CleanupPhase) {
        _ = reach(phase)
        let mark = notifications.calls.count

        _ = makeTimer()

        #expect(Array(notifications.calls.dropFirst(mark)) == expectedCleanup(phase))
    }

    @Test func activationAfterBreakEndedInTheBackgroundKeepsTheBreakAlert() {
        let timer = makeWaitingForBreak()
        timer.startBreak()
        clock.advance(by: 600)
        let mark = notifications.calls.count

        timer.activate()

        // Since I13 the Break alert is the current alert while completed.
        #expect(timer.state.phase == .completed)
        #expect(Array(notifications.calls.dropFirst(mark)) == [
            .cancel(phase: .runningB),
            .removeDelivered(phase: .runningA),
        ])
    }

    @Test func activationAfterFocusEndedInTheBackgroundKeepsTheFocusAlert() {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 600)
        let mark = notifications.calls.count

        timer.activate()

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(Array(notifications.calls.dropFirst(mark)) == [.removeDelivered(phase: .runningB)])
    }
}
