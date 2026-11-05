import Foundation
import Testing
@testable import FocusTimer

@MainActor
struct TimerStoreMigrationTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    let savedConfiguration = TimerStore.Configuration(durationASeconds: 25 * 60, durationBSeconds: 5 * 60)

    func seed(
        configuration: TimerStore.Configuration? = nil,
        state: TimerStore.TimerState? = nil,
        version: Data? = nil
    ) {
        if let configuration, let data = try? JSONEncoder().encode(configuration) {
            store.setData(data, forKey: "config")
        }
        if let state, let data = try? JSONEncoder().encode(state) {
            store.setData(data, forKey: "state")
        }
        if let version {
            store.setData(version, forKey: "schemaVersion")
        }
    }

    func versionData(_ version: Int) -> Data {
        (try? JSONEncoder().encode(version)) ?? Data()
    }

    /// Loads a store and returns it with the keys it wrote while loading.
    func load() -> (TimerStore, [String]) {
        let seededWrites = store.writtenKeys.count
        let timer = TimerStore(clock: clock, store: store, notifications: notifications)
        return (timer, Array(store.writtenKeys.dropFirst(seededWrites)))
    }

    func savedVersion() -> Int? {
        store.values["schemaVersion"].flatMap { try? JSONDecoder().decode(Int.self, from: $0) }
    }

    func state(_ unversioned: UnversionedState) -> TimerStore.TimerState {
        // Inside both saved durations, so the I12 cap leaves it alone.
        let deadline = clock.now.addingTimeInterval(200)
        return switch unversioned {
        case .idle: TimerStore.TimerState()
        case .runningFocus: TimerStore.TimerState(phase: .runningA, endTimestamp: deadline, paused: false, remainingSeconds: nil)
        case .runningBreak: TimerStore.TimerState(phase: .runningB, endTimestamp: deadline, paused: false, remainingSeconds: nil)
        case .pausedFocus: TimerStore.TimerState(phase: .runningA, endTimestamp: nil, paused: true, remainingSeconds: 1_494)
        case .pausedBreak: TimerStore.TimerState(phase: .runningB, endTimestamp: nil, paused: true, remainingSeconds: 200)
        case .waitingForBreak: TimerStore.TimerState(phase: .waitingForAConfirm)
        }
    }

    // MARK: Unversioned records

    @Test func unversionedWaitingStateResetsAndKeepsTheConfiguration() {
        seed(configuration: savedConfiguration, state: state(.waitingForBreak))
        let savedConfig = store.values["config"]

        let (timer, _) = load()

        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.configuration == savedConfiguration)
        #expect(store.values["config"] == savedConfig)
        #expect(savedVersion() == TimerStore.currentSchemaVersion)
        #expect(timer.statusMessage != TimerStore.repairNotice)
    }

    @Test(arguments: [UnversionedState.idle, .runningFocus, .runningBreak, .pausedFocus, .pausedBreak])
    func unversionedRecordsKeepTheirValues(_ unversioned: UnversionedState) {
        seed(configuration: savedConfiguration, state: state(unversioned))
        let savedConfig = store.values["config"]
        let savedState = store.values["state"]
        let active = unversioned != .idle

        let (timer, writes) = load()

        #expect(timer.configuration == savedConfiguration)
        #expect(timer.state.ignoringCycle == state(unversioned))
        #expect((timer.state.cycleID != nil) == active)
        #expect(store.values["config"] == savedConfig)
        if active {
            // The 1 → 2 step saves the cycle ID it added.
            #expect(store.values["state"].flatMap { try? JSONDecoder().decode(TimerStore.TimerState.self, from: $0) } == timer.state)
        } else {
            #expect(store.values["state"] == savedState)
        }
        #expect(savedVersion() == TimerStore.currentSchemaVersion)
        #expect(writes == (active ? ["state", "schemaVersion"] : ["schemaVersion"]))
        #expect(notifications.pendingCalls.isEmpty)
        #expect(timer.statusMessage != TimerStore.repairNotice)
    }

    @Test(arguments: TimedPhase.allCases)
    func unversionedRunningStateWithPassedDeadlineReconciles(_ timed: TimedPhase) {
        seed(
            configuration: savedConfiguration,
            state: TimerStore.TimerState(
                phase: timed == .focus ? .runningA : .runningB,
                endTimestamp: clock.now.addingTimeInterval(-60),
                paused: false,
                remainingSeconds: nil
            )
        )

        let (timer, _) = load()

        let expected = timed == .focus ? TimerStore.TimerState(phase: .waitingForAConfirm) : TimerStore.TimerState(phase: .completed)
        #expect(timer.state.ignoringCycle == expected)
        #expect(timer.configuration == savedConfiguration)
        #expect(savedVersion() == TimerStore.currentSchemaVersion)
    }

    @Test func unversionedRecordsAreMigratedThenRepaired() {
        seed(configuration: TimerStore.Configuration(durationASeconds: 30, durationBSeconds: 60))

        let (timer, _) = load()

        #expect(timer.configuration == TimerStore.Configuration(durationASeconds: 60, durationBSeconds: 60))
        #expect(savedVersion() == TimerStore.currentSchemaVersion)
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    // MARK: Fresh install and current version

    @Test func freshInstallWritesOnlyTheVersion() {
        let (timer, writes) = load()

        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == TimerStore.TimerState())
        #expect(writes == ["schemaVersion"])
        #expect(savedVersion() == TimerStore.currentSchemaVersion)
    }

    @Test func currentVersionLoadsWithoutWrites() {
        var pausedFocus = state(.pausedFocus)
        pausedFocus.cycleID = UUID()
        seed(configuration: savedConfiguration, state: pausedFocus, version: versionData(TimerStore.currentSchemaVersion))
        let savedValues = store.values

        let (timer, writes) = load()

        #expect(timer.configuration == savedConfiguration)
        #expect(timer.state == pausedFocus)
        #expect(writes.isEmpty)
        #expect(store.values == savedValues)
    }

    // MARK: Newer or unreadable versions

    @Test(arguments: [
        TimerStore.currentSchemaVersion + 1, -1,
    ])
    func unsupportedVersionUsesDefaultsAndWritesNothing(_ version: Int) {
        seed(configuration: savedConfiguration, state: state(.pausedFocus), version: versionData(version))
        let savedValues = store.values

        let (timer, writes) = load()

        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == TimerStore.TimerState())
        #expect(writes.isEmpty)
        #expect(store.values == savedValues)
        #expect(notifications.pendingCalls.isEmpty)
    }

    @Test func unreadableVersionUsesDefaultsAndWritesNothing() {
        seed(configuration: savedConfiguration, state: state(.pausedFocus), version: Data("not a version".utf8))
        let savedValues = store.values

        let (timer, writes) = load()

        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == TimerStore.TimerState())
        #expect(writes.isEmpty)
        #expect(store.values == savedValues)
    }
}
