# I03-I04 Inject the clock and persistence store into TimerStore

Status: in progress (2026-10-20); plan group 1 (clock) committed in `092d4d5`; plan group 2 (store) implemented and built, not committed; simulator checks not run. Implements roadmap phases I03 and I04 in the [iOS roadmap](../roadmap.md), combined by user decision.

Context: [mission](../mission.md), [tech stack](../tech-stack.md), previous phase [I02](I02-exercise-lifecycle-notifications.md).

Roadmap exit checks:

- I03: existing flow preserved; production uses Date; tests can control now.
- I04: all reads and writes use the supplied store; isolated defaults do not affect production data.

## Requirements

### Scope

- **Clock (I03):** introduce a small clock protocol and route every current-time read in `TimerStore` through an injected instance. Production uses a system clock that returns `Date()`.
- **Store (I04):** introduce a small key-value storage protocol, conform `UserDefaults` to it, and have `TimerStore` hold one injected store and use it for every read and write. This fixes the known gap in the [tech stack](../tech-stack.md): `persistConfiguration` and `persistState` default to `UserDefaults.standard`, ignoring the store passed to `init`.
- Make `TimerStore`'s initializer internal so a future test target can construct an instance with a fake clock and store. `TimerStore.shared` remains the app's single instance and uses the production clock and `UserDefaults.standard`.

### Non-goals

- `NotificationScheduler`'s clock read (`deadline.timeIntervalSinceNow` for the trigger interval) and its static calls: left for I05's notification boundary and recorded as a limitation.
- The XCTest target and tests (I05, I06). No test files are added.
- Validation, schema versioning, migration, and recovery of stored data (I07 to I09). Keys `config` and `state` and their JSON encoding stay unchanged.
- Any change to timer behavior, UI, notifications, or the one-second ticker.
- `chrome/`.

### Decisions

- Phases I03 and I04 are combined into one phase and branch, delivered as two separately reviewable commits: clock first, then store. The roadmap rows are merged at close-out.
- Clock: a small protocol, for example `protocol Clock { var now: Date { get } }` with `struct SystemClock: Clock` returning `Date()`. Names may be adjusted during implementation, but the shape stays this small.
- Store: a small protocol, for example `protocol KeyValueStore { func data(forKey: String) -> Data?; func setData(_ data: Data, forKey: String) }`. `UserDefaults` conforms through an extension (it already has `data(forKey:)`; `setData` forwards to `set(_:forKey:)`, because a protocol requirement typed `Data?` is not satisfied by `UserDefaults.set(_: Any?, forKey:)`).
- Initializer: `init(clock: any Clock = SystemClock(), store: any KeyValueStore = UserDefaults.standard)`, internal access. `shared` keeps calling it with defaults.
- `NotificationScheduler` is unchanged; it still reads the real clock.
- Validation: agent build plus agent-driven simulator run. The user may additionally confirm on their own simulator; that is optional and recorded as user-reported if given.

### Context from the current code

- `TimerStore.swift` reads the clock in `pauseOrResume` (`Date()` on resume, `deadline.timeIntervalSinceNow` on pause), `reconcileWithCurrentTime` (`deadline <= Date()`), `startPhase` (`Date()`), and `updateDisplayedTime` (`deadline.timeIntervalSinceNow`). Each becomes a read of `clock.now`, with `timeIntervalSinceNow` replaced by `deadline.timeIntervalSince(clock.now)`.
- `init(defaults:)` decodes from the passed store, while `persistConfiguration(defaults:)` and `persistState(defaults:)` default to `.standard`.
- The project uses file-system synchronized groups, so new Swift files in `ios/FocusTimer/FocusTimer/` are included without editing `project.pbxproj`. The target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency; the new protocols and types follow that default unless the compiler requires otherwise.

### Affected components

- `ios/FocusTimer/FocusTimer/TimerStore.swift`: initializer, clock reads, persistence reads and writes.
- New file(s) in `ios/FocusTimer/FocusTimer/` for `Clock`/`SystemClock` and `KeyValueStore` with the `UserDefaults` conformance (one file per protocol, or one small shared file; decide during implementation).
- Unchanged: `NotificationScheduler.swift`, `FocusTimerApp.swift`, `ContentView.swift`, `project.pbxproj`.

### Invariants to preserve

Single authoritative timer state (`TimerStore.shared` stays the only production instance), explicit Break confirmation, local persistence (same keys and encoding in `UserDefaults.standard`), deadline-based recovery (absolute deadlines, reconciled on launch and activation).

## Plan

1. Clock injection (commit 1, I03)
   - [x] Add `Clock` and `SystemClock`.
   - [x] Add a stored `clock` property to `TimerStore` and an internal initializer parameter defaulting to `SystemClock()`.
   - [x] Replace every `Date()` and `timeIntervalSinceNow` in `TimerStore` with reads of `clock.now`.
   - [x] Build; confirm with `grep` that `TimerStore.swift` has no direct `Date()` or `timeIntervalSinceNow`.
2. Store injection (commit 2, I04)
   - [x] Add `KeyValueStore` and the `UserDefaults` conformance.
   - [x] Store the injected store once in `TimerStore`; route `decode`, `persistConfiguration`, and `persistState` through it; remove the `.standard` default parameters from the persist methods.
   - [x] Build; confirm with `grep` that `.standard` appears only as the initializer's default argument.
3. Verification and close-out
   - [ ] Agent-driven simulator run of the flow checks below, using a device other than the user's booted one.
   - [ ] Record results; update the [tech stack](../tech-stack.md) gap note (store fixed; clock injected; notification scheduler still live) and its State row (internal initializer, injected clock and store).
   - [ ] Set status to verified only with evidence; merge the I03 and I04 rows into the completed table in the roadmap; the user runs `/update-changelog` before merging.

## Validation

### Agent-run

Toolchain checks as in `AGENTS.md`, then the build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FocusTimerDerivedData CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **` after each commit, with no new warnings in the changed files.

Static checks on `ios/FocusTimer/FocusTimer/TimerStore.swift`:

- No `Date()` and no `timeIntervalSinceNow` (clock reads go through the injected clock).
- `.standard` appears only as the initializer's default store; every `data(forKey:)` and write uses the stored store.

Agent-driven simulator run (iPhone 17 Pro, iOS 26.5, separate from the user's booted device), default one-minute durations, mirroring I01/I02 rows:

1. Saved state survives the update: before installing the new build, leave the app in a known state (for example waiting for Break confirmation); after installing, it relaunches in that state with durations retained (same keys and encoding).
2. Start: Focus counts down once per second.
3. Pause, wait, Resume: time frozen while paused, then continues from the frozen value (P1, P2).
4. Cancel: Ready with durations retained (C1).
5. Force-quit and relaunch before the deadline: correct remaining time (R1).
6. Force-quit and relaunch after the deadline: waiting for Break confirmation; Break not started (R2).
7. Start Break, then let it expire: idle with durations retained.

### User-reported (optional)

The user may repeat any of the steps above on their own simulator in Xcode; results are recorded as user-reported.

### Unverified after this phase

- "Tests can control now" and "isolated defaults do not affect production data" are shown by design and static checks only; they are proven by tests in I05 and I06.
- `NotificationScheduler` still reads the real clock (I05).
- Deferred I02 rows (suspension, notifications, R3, R5), physical device.

## Results

### Plan group 1: clock injection (agent-run, 2026-10-20)

- Change: new `ios/FocusTimer/FocusTimer/Clock.swift` with `Clock` and `SystemClock`; `TimerStore` holds `private let clock: any Clock`, and its initializer is now internal: `init(clock: any Clock = SystemClock(), defaults: UserDefaults = .standard)`. The five clock reads in `startPhase`, `pauseOrResume` (two), `reconcileWithCurrentTime`, and `updateDisplayedTime` use `clock.now` / `timeIntervalSince(clock.now)`.
- Build: Xcode 27.0, the Validation build command with `DEVELOPER_DIR`; `** BUILD SUCCEEDED **`. No compiler warnings; one tool warning from `appintentsmetadataprocessor` ("no AppIntents.framework dependency found"), unrelated to this change.
- Static check: `grep -n "Date()\|timeIntervalSinceNow" TimerStore.swift` returns nothing.
- Not yet run: simulator flow checks (after plan group 2).

### Plan group 2: store injection (agent-run, 2026-10-20)

- Change: new `ios/FocusTimer/FocusTimer/KeyValueStore.swift` with `KeyValueStore` (`data(forKey:)`, `setData(_:forKey:)`) and a `UserDefaults` conformance whose `setData` forwards to `set(_:forKey:)`. `TimerStore` holds `private let store: any KeyValueStore`; the initializer is `init(clock: any Clock = SystemClock(), store: any KeyValueStore = UserDefaults.standard)`. `decode`, `persistConfiguration`, and `persistState` use the stored store; the persist methods no longer take a `defaults` parameter. Keys `config` and `state` and the JSON encoding are unchanged.
- Build: Xcode 27.0, the Validation build command with `DEVELOPER_DIR`; `** BUILD SUCCEEDED **`. No compiler warnings; the same unrelated `appintentsmetadataprocessor` tool warning as group 1.
- Static checks: in `TimerStore.swift`, `.standard` appears only in the initializer's default argument (line 38); reads and writes are `store.data(forKey:)` and `store.setData(_:forKey:)` (lines 198, 204, 209); still no `Date()` or `timeIntervalSinceNow`.
- Not yet run: simulator flow checks, including saved state surviving the update (Validation step 1).
