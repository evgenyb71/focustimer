import Foundation
import Testing
@testable import FocusTimer

/// The Debug-only short minute for manual checks, injected directly. Each `makeTimer` after the first stands
/// for a new process.
@MainActor
struct TimerStoreShortMinuteTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    func makeTimer(secondsPerMinute: Int = 10) -> TimerStore {
        TimerStore(clock: clock, store: store, notifications: notifications, secondsPerMinute: secondsPerMinute)
    }

    func savedConfiguration() -> TimerStore.Configuration? {
        store.values["config"].flatMap { try? JSONDecoder().decode(TimerStore.Configuration.self, from: $0) }
    }

    func seed(_ state: TimerStore.TimerState) {
        if let data = try? JSONEncoder().encode(state),
           let version = try? JSONEncoder().encode(TimerStore.currentSchemaVersion) {
            store.setData(data, forKey: "state")
            store.setData(version, forKey: "schemaVersion")
        }
    }

    // MARK: Real minutes by default

    @Test func theDefaultRunsRealMinutes() {
        let timer = TimerStore(clock: clock, store: store, notifications: notifications)
        timer.configuration.durationASeconds = 120

        timer.startFocus()

        #expect(timer.secondsPerMinute == 60)
        #expect(timer.state.endTimestamp == clock.now.addingTimeInterval(120))
        #expect(notifications.calls.last == .schedule(phase: .runningA, deadline: clock.now.addingTimeInterval(120), now: clock.now))
    }

    // MARK: A shortened minute

    @Test func phasesAndAlertsFollowTheShortenedMinute() {
        let timer = makeTimer()
        timer.configuration.durationBSeconds = 120

        timer.startFocus()
        let focusDeadline = clock.now.addingTimeInterval(10)
        #expect(timer.state.endTimestamp == focusDeadline)
        #expect(timer.displayedSeconds == 10)
        #expect(notifications.calls.last == .schedule(phase: .runningA, deadline: focusDeadline, now: clock.now))

        clock.advance(by: 10)
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .waitingForAConfirm)

        timer.startBreak()
        let breakDeadline = clock.now.addingTimeInterval(20)
        #expect(timer.state.endTimestamp == breakDeadline)
        #expect(notifications.calls.contains(.schedule(phase: .runningB, deadline: breakDeadline, now: clock.now)))

        clock.advance(by: 20)
        timer.reconcileWithCurrentTime()
        #expect(timer.state.phase == .completed)
    }

    @Test func durationsStayInWholeMinutes() {
        let timer = makeTimer()
        timer.configuration.durationBSeconds = 120

        timer.startFocus()

        let minutes = TimerStore.Configuration(durationASeconds: 60, durationBSeconds: 120)
        #expect(timer.configuration == minutes)
        #expect(savedConfiguration() == minutes)
    }

    @Test func pauseKeepsTheShortenedRemainingTime() {
        let timer = makeTimer()
        timer.startFocus()
        clock.advance(by: 4)

        timer.pauseOrResume()

        #expect(timer.state.remainingSeconds == 6)
        #expect(timer.displayedSeconds == 6)

        clock.advance(by: 100)
        timer.pauseOrResume()
        #expect(timer.state.endTimestamp == clock.now.addingTimeInterval(6))
    }

    // MARK: Switching between real and short minutes

    @Test func aRealMinuteDeadlineIsCappedToTheShortenedLengthAtLaunchWithoutNotice() {
        let real = makeTimer(secondsPerMinute: 60)
        real.startFocus()
        let calls = notifications.calls.count

        let launched = makeTimer()

        #expect(launched.state.endTimestamp == clock.now.addingTimeInterval(10))
        #expect(launched.noticeMessage == nil)
        #expect(Array(notifications.calls.dropFirst(calls)).contains(
            .schedule(phase: .runningA, deadline: clock.now.addingTimeInterval(10), now: clock.now)
        ))
    }

    @Test func aPausedTimeLongerThanTheShortenedLengthIsClampedWithNotice() {
        seed(TimerStore.TimerState(phase: .runningA, paused: true, remainingSeconds: 50, cycleID: UUID()))

        let launched = makeTimer()

        #expect(launched.state.remainingSeconds == 10)
        #expect(launched.statusMessage == TimerStore.repairNotice)
    }

    // MARK: Accepted values

    @Test(arguments: [1, 10, 59, 60])
    func valuesFromOneToSixtyAreUsed(_ value: Int) {
        #expect(makeTimer(secondsPerMinute: value).secondsPerMinute == value)
    }

    @Test(arguments: [0, -1, 61, 1_000])
    func otherValuesMeanRealMinutes(_ value: Int) {
        let timer = makeTimer(secondsPerMinute: value)

        timer.startFocus()

        #expect(timer.secondsPerMinute == 60)
        #expect(timer.state.endTimestamp == clock.now.addingTimeInterval(60))
    }
}
