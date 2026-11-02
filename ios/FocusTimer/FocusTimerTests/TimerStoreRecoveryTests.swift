import Foundation
import Testing
@testable import FocusTimer

@MainActor
struct TimerStoreRecoveryTests {
    let clock = FakeClock()
    let store = InMemoryStore()
    let notifications = RecordingNotificationScheduler()

    let savedConfiguration = TimerStore.Configuration(durationASeconds: 25 * 60, durationBSeconds: 5 * 60)
    let garbage = Data("not json".utf8)
    let cycleID = UUID()

    func encoded<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    func seed(config: Data? = nil, state: Data? = nil, version: Data? = TimerStoreRecoveryTests.encodedCurrentVersion) {
        if let config { store.setData(config, forKey: "config") }
        if let state { store.setData(state, forKey: "state") }
        if let version { store.setData(version, forKey: "schemaVersion") }
    }

    static var encodedCurrentVersion: Data {
        (try? JSONEncoder().encode(TimerStore.currentSchemaVersion)) ?? Data()
    }

    func load() -> (TimerStore, [String]) {
        let seededWrites = store.writtenKeys.count
        let timer = TimerStore(clock: clock, store: store, notifications: notifications)
        return (timer, Array(store.writtenKeys.dropFirst(seededWrites)))
    }

    func savedVersion() -> Int? {
        store.values["schemaVersion"].flatMap { try? JSONDecoder().decode(Int.self, from: $0) }
    }

    var runningFocus: TimerStore.TimerState {
        TimerStore.TimerState(phase: .runningA, endTimestamp: clock.now.addingTimeInterval(30), paused: false, remainingSeconds: nil, cycleID: cycleID)
    }

    // MARK: Unsupported versions

    @Test(arguments: [TimerStore.currentSchemaVersion + 1, -1])
    func unsupportedVersionShowsNoticeAndWritesNothing(_ version: Int) {
        seed(config: encoded(savedConfiguration), state: encoded(runningFocus), version: encoded(version))
        let savedValues = store.values

        let (timer, writes) = load()

        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.statusMessage == TimerStore.repairNotice)
        #expect(writes.isEmpty)
        #expect(store.values == savedValues)
    }

    @Test(arguments: [Data("not a version".utf8), Data("2".utf8) + Data("x".utf8)])
    func firstSaveAfterUnsupportedVersionWritesCurrentVersion(_ version: Data) {
        seed(config: encoded(savedConfiguration), state: encoded(runningFocus), version: version)
        let (timer, _) = load()

        timer.startOrConfirmBreak()

        #expect(savedVersion() == TimerStore.currentSchemaVersion)
        let (reloaded, writes) = load()
        #expect(reloaded.state.phase == .runningA)
        #expect(reloaded.configuration == TimerStore.Configuration())
        #expect(reloaded.statusMessage != TimerStore.repairNotice)
        #expect(writes.isEmpty)
    }

    @Test func versionIsWrittenOnlyOnTheFirstSave() {
        seed(config: encoded(savedConfiguration), version: encoded(TimerStore.currentSchemaVersion + 1))
        let (timer, _) = load()
        let seededVersionWrites = store.writtenKeys.filter { $0 == "schemaVersion" }.count

        timer.startOrConfirmBreak()
        let afterFirstSave = store.writtenKeys.filter { $0 == "schemaVersion" }.count - seededVersionWrites
        timer.pauseOrResume()
        timer.cancel()

        #expect(afterFirstSave == 1)
        #expect(store.writtenKeys.filter { $0 == "schemaVersion" }.count - seededVersionWrites == 1)
    }

    // MARK: One bad record

    @Test func corruptStateKeepsConfigurationAndIsReplaced() {
        seed(config: encoded(savedConfiguration), state: garbage)

        let (timer, writes) = load()

        #expect(timer.configuration == savedConfiguration)
        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.statusMessage == TimerStore.repairNotice)
        #expect(writes == ["state"])
        #expect(store.values["state"].flatMap { try? JSONDecoder().decode(TimerStore.TimerState.self, from: $0) } == TimerStore.TimerState())
        #expect(notifications.pendingCalls == [.cancelAll])
    }

    @Test func corruptConfigurationKeepsRunningStateAndDeadline() {
        let running = runningFocus
        seed(config: garbage, state: encoded(running))

        let (timer, writes) = load()

        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == running)
        #expect(timer.statusMessage == TimerStore.repairNotice)
        #expect(writes == ["config"])
        #expect(notifications.pendingCalls.isEmpty)
    }

    @Test func bothRecordsCorruptStillStarts() {
        seed(config: garbage, state: garbage)

        let (timer, _) = load()
        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.statusMessage == TimerStore.repairNotice)

        timer.startOrConfirmBreak()
        #expect(timer.state.phase == .runningA)
        let (reloaded, writes) = load()
        #expect(reloaded.state.phase == .runningA)
        #expect(reloaded.statusMessage != TimerStore.repairNotice)
        #expect(writes.isEmpty)
    }

    // MARK: Unknown or wrong-typed values

    @Test func unknownPhaseFallsBackWholeRecordAndKeepsConfiguration() {
        seed(config: encoded(savedConfiguration), state: Data(#"{"phase":"finished","paused":false}"#.utf8))

        let (timer, _) = load()

        #expect(timer.configuration == savedConfiguration)
        #expect(timer.state == TimerStore.TimerState())
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    @Test func wrongTypedDurationsFallBackWholeRecordAndKeepState() {
        let paused = TimerStore.TimerState(phase: .runningA, endTimestamp: nil, paused: true, remainingSeconds: 30, cycleID: cycleID)
        seed(config: Data(#"{"durationASeconds":"25","durationBSeconds":300}"#.utf8), state: encoded(paused))

        let (timer, _) = load()

        #expect(timer.configuration == TimerStore.Configuration())
        #expect(timer.state == paused)
        #expect(timer.statusMessage == TimerStore.repairNotice)
    }

    // MARK: Regressions

    @Test func missingRecordsAtCurrentVersionShowNoNotice() {
        seed()

        let (timer, writes) = load()

        #expect(timer.statusMessage != TimerStore.repairNotice)
        #expect(writes.isEmpty)
    }
}
