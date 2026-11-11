import Foundation
import Testing
import UserNotifications
@testable import FocusTimer

/// The denied hint and the scheduling-failure notice. Neither may block the timer.
@MainActor
struct TimerStoreAlertPermissionTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer(status: UNAuthorizationStatus = .authorized) async -> TimerStore {
        notifications.status = status
        let timer = TimerStore(clock: clock, store: store, notifications: notifications)
        await timer.alertPermissionCheck?.value
        return timer
    }

    // MARK: Denied hint

    @Test func deniedShowsTheHint() async {
        let timer = await makeTimer(status: .denied)

        #expect(timer.alertsDenied)
        #expect(timer.alertsHint == TimerStore.alertsDeniedHint)
    }

    @Test(arguments: [UNAuthorizationStatus.notDetermined, .authorized, .provisional, .ephemeral])
    func otherStatusesShowNoHint(status: UNAuthorizationStatus) async {
        let timer = await makeTimer(status: status)

        #expect(!timer.alertsDenied)
        #expect(timer.alertsHint == nil)
    }

    @Test func activationAfterAllowingInSettingsRemovesTheHint() async {
        let timer = await makeTimer(status: .denied)

        notifications.status = .authorized
        timer.activate()
        await timer.alertPermissionCheck?.value

        #expect(timer.alertsHint == nil)
    }

    @Test func activationAfterDenyingInSettingsAddsTheHint() async {
        let timer = await makeTimer(status: .authorized)

        notifications.status = .denied
        timer.activate()
        await timer.alertPermissionCheck?.value

        #expect(timer.alertsHint == TimerStore.alertsDeniedHint)
    }

    @Test func aRecheckAfterTheLaunchPromptShowsTheHint() async {
        let timer = await makeTimer(status: .notDetermined)

        notifications.status = .denied
        timer.checkAlertPermission()
        await timer.alertPermissionCheck?.value

        #expect(timer.alertsHint == TimerStore.alertsDeniedHint)
    }

    @Test func anOlderReadFinishingLastDoesNotOverwriteANewerOne() async {
        notifications.holdsStatusReads = true
        let timer = TimerStore(clock: clock, store: store, notifications: notifications)
        let launchRead = timer.alertPermissionCheck
        timer.checkAlertPermission()
        let newerRead = timer.alertPermissionCheck
        while notifications.heldStatusReads.count < 2 {
            await Task.yield()
        }

        // The newer read sees alerts turned off; the launch read's earlier snapshot returns afterwards.
        notifications.heldStatusReads[1].resume(returning: .denied)
        await newerRead?.value
        notifications.heldStatusReads[0].resume(returning: .authorized)
        await launchRead?.value

        #expect(timer.alertsHint == TimerStore.alertsDeniedHint)
    }

    @Test func deniedAlertsDoNotBlockAFullCycle() async {
        let timer = await makeTimer(status: .denied)

        timer.startOrConfirmBreak()
        #expect(timer.state.phase == .runningA)
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .waitingForAConfirm)
        timer.startOrConfirmBreak()
        #expect(timer.state.phase == .runningB)
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .completed)
        timer.startOrConfirmBreak()
        #expect(timer.state.phase == .runningA)
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        timer.startOrConfirmBreak()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        timer.done()
        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.alertsHint == TimerStore.alertsDeniedHint)
    }

    // MARK: Scheduling failure

    @Test func failureForTheCurrentRunShowsTheNoticeAndKeepsTheTimer() async throws {
        let timer = await makeTimer()
        timer.startFocus()
        let state = timer.state

        let failure = try #require(notifications.failureHandlers.last)
        failure()

        #expect(timer.noticeMessage == TimerStore.schedulingFailureNotice)
        #expect(timer.statusMessage == TimerStore.schedulingFailureNotice)
        #expect(timer.state == state)
        #expect(timer.state.endTimestamp == clock.now.addingTimeInterval(60))
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .waitingForAConfirm)
    }

    @Test func failureForBreakShowsTheNotice() async throws {
        let timer = await makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        timer.startOrConfirmBreak()

        let failure = try #require(notifications.failureHandlers.last)
        failure()

        #expect(timer.noticeMessage == TimerStore.schedulingFailureNotice)
        #expect(timer.state.phase == .runningB)
    }

    @Test func failureAfterResumeShowsTheNotice() async throws {
        let timer = await makeTimer()
        timer.startFocus()
        timer.pauseOrResume()
        timer.pauseOrResume()

        let failure = try #require(notifications.failureHandlers.last)
        failure()

        #expect(timer.noticeMessage == TimerStore.schedulingFailureNotice)
    }

    @Test func lateFailureAfterTheNextPhaseShowsNothing() async throws {
        let timer = await makeTimer()
        timer.startFocus()
        let focusFailure = try #require(notifications.failureHandlers.last)
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        timer.startOrConfirmBreak()

        focusFailure()

        #expect(timer.noticeMessage == nil)
    }

    @Test func lateFailureFromAnEarlierCycleShowsNothing() async throws {
        let timer = await makeTimer()
        timer.startFocus()
        let firstFailure = try #require(notifications.failureHandlers.last)
        timer.cancel()
        timer.startFocus()

        firstFailure()

        #expect(timer.noticeMessage == nil)
    }

    @Test func lateFailureAfterPauseOrAnotherDeadlineShowsNothing() async throws {
        let timer = await makeTimer()
        timer.startFocus()
        let firstFailure = try #require(notifications.failureHandlers.last)
        timer.pauseOrResume()

        firstFailure()
        #expect(timer.noticeMessage == nil)

        clock.advance(by: 10)
        timer.pauseOrResume()
        firstFailure()
        #expect(timer.noticeMessage == nil)
    }

    @Test func lateFailureAfterCancelShowsNothing() async throws {
        let timer = await makeTimer()
        timer.startFocus()
        let failure = try #require(notifications.failureHandlers.last)
        timer.cancel()

        failure()

        #expect(timer.noticeMessage == nil)
    }

    @Test func failureWhileDeniedShowsOnlyTheHint() async throws {
        let timer = await makeTimer(status: .denied)
        timer.startFocus()

        let failure = try #require(notifications.failureHandlers.last)
        failure()

        #expect(timer.noticeMessage == nil)
        #expect(timer.alertsHint == TimerStore.alertsDeniedHint)
    }

    @Test func theNoticeClearsWhenFocusEnds() async throws {
        let timer = await makeTimer()
        timer.startFocus()
        let failure = try #require(notifications.failureHandlers.last)
        failure()

        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(timer.noticeMessage == nil)
        #expect(timer.statusMessage == "Take a break when you're ready.")
    }

    @Test func theNoticeClearsWhenBreakEnds() async throws {
        let timer = await makeTimer()
        timer.startFocus()
        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()
        timer.startOrConfirmBreak()
        let failure = try #require(notifications.failureHandlers.last)
        failure()

        clock.advance(by: 60)
        timer.reconcileWithCurrentTime()

        #expect(timer.state.phase == .completed)
        #expect(timer.noticeMessage == nil)
    }

    @Test func aRepairNoticeStaysWhenAPhaseEndsAtLaunch() async {
        // A Focus that ended while closed reaches waiting; the unreadable configuration adds the repair notice.
        let saved = TimerStore.TimerState(phase: .runningA, endTimestamp: clock.now.addingTimeInterval(-1), cycleID: UUID())
        if let state = try? JSONEncoder().encode(saved),
           let version = try? JSONEncoder().encode(TimerStore.currentSchemaVersion) {
            store.setData(state, forKey: "state")
            store.setData(Data("not json".utf8), forKey: "config")
            store.setData(version, forKey: "schemaVersion")
        }

        let timer = await makeTimer()

        #expect(timer.state.phase == .waitingForAConfirm)
        #expect(timer.noticeMessage == TimerStore.repairNotice)
    }

    @Test func theNoticeClearsOnTheNextTransition() async throws {
        let timer = await makeTimer()
        timer.startFocus()
        let failure = try #require(notifications.failureHandlers.last)
        failure()

        timer.pauseOrResume()

        #expect(timer.noticeMessage == nil)
    }
}
