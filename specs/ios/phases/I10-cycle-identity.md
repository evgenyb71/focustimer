# I10 Persist a cycle identity and validate action provenance

Status: verified (2026-10-26), with one deferral: 80 test functions (79 passed, 1 expected failure for I12), agent-run on iPhone 17 Pro iOS 26.5; user-reported Cmd+U all passed and an upgrade check of version 1 data on the iPhone 18 Pro Max (iOS 27.0). The manual stale-alert check is a ToDo, deferred by the user; the exit check is covered by unit tests only. Implements roadmap phase I10, "Persist a cycle identity and validate action provenance". Commits `ac368fe` (start-phase model check) and `f434784`, merged to `main` as `0d7b35c` and pushed. Branch `feat/I10-cycle-identity`.

Context: [roadmap](../roadmap.md), [mission](../mission.md), [tech stack](../tech-stack.md), previous phase [I09](I09-recover-saved-records.md).

Roadmap exit check: an old Focus notification cannot start Break in a newer cycle; duplicate actions are harmless.

## Requirements

### Scope

Each Focus → Break cycle gets a persisted identity. Completion notifications carry it, and the notification OK action starts Break only when its identity matches the current cycle. Today the delegate checks only the action string and the current phase. An OK tapped on an alert from an earlier cycle can therefore start Break in a later cycle that is waiting for confirmation.

### Decisions (user, 2026-10-26)

- **Scope: ID in the state and in `userInfo`.** The cycle ID is saved in the timer state and added to each completion notification's `userInfo`. The delegate validates it. The request identifiers stay `focusComplete` and `breakComplete`. Putting the cycle in identifiers and removing obsolete delivered alerts belong to I11.
- **A UUID per Focus start.** Each Focus start creates a new UUID. It is kept through waiting for confirmation and Break, and removed when the cycle ends (Break completes or Cancel). It cannot repeat after a cancel, a recovery reset, or a reinstall.
- **Stale or missing ID: ignore.** Only an action whose ID matches the current cycle can start Break. An action with a different ID, or with no ID (scheduled by a pre-I10 build), opens the app and changes nothing. The user then starts Break in the app.
- **Migration 1 → 2 assigns an ID.** A saved active cycle (running or paused Focus or Break, or waiting for Break) gets a fresh UUID and keeps its timer. No notice is shown, as with the 0 → 1 step. Alerts scheduled before the upgrade carry no ID, so their OK is ignored.
- **Repair adds a missing ID.** A version 2 record with an active phase but no cycle ID is repaired by assigning a fresh UUID, keeping the phase and the deadline. The repair is saved and the I07 correction notice is shown.
- **Validation:** agent-run unit tests, user-reported Cmd+U, and a manual stale-alert check on the user's simulator.

### Agent decisions within the user's choices (open to revision)

- **Field:** `TimerState.cycleID: UUID?`, encoded as a string. Idle has no ID. The I07 invariant becomes: idle has no cycle ID, every other phase has one. A stray ID on idle is removed by the existing repair.
- **The ID stays the same into Break.** Break is part of the same cycle, so the Break notification carries the same ID. Nothing reads it yet; I16 (notification Done) will.
- **Duplicate actions:** a second OK for the same cycle after Break has started finds the phase `runningB` and does nothing. The existing `startBreak` guard already covers this; I10 adds tests for it.
- **Order inside the action:** reconcile with the current time first, as today, then check the ID and the phase. A Focus whose deadline has passed but was not yet reconciled, because the app was suspended, still starts Break when its ID matches.
- **No injected UUID generator.** Tests read the ID from the store after Start, and seed records with known UUIDs. Add a generator only if a test cannot be written without one.
- **Notification boundary:** `NotificationScheduling.scheduleCompletion` takes the cycle ID, and the recording test scheduler records it. `userInfo` uses one key, `cycleID`, as a UUID string.
- **Delegate:** extract the ID from `userInfo` and pass it to a `TimerStore` method, for example `startBreakFromNotification(cycleID:)`, which owns the comparison. `FocusTimerApp.swift` only parses the response.
- **Schema:** `currentSchemaVersion` becomes 2 and `migrations` gains one step, 1 → 2. The step decodes the saved state, adds a UUID when the phase is active, and writes it back. A state it cannot decode is left for the I09 recovery.

### Non-goals

- Cycle-scoped request identifiers and removal of obsolete pending or delivered alerts (I11).
- Pause at expiry, clock edges, and duplicate completion callbacks (I12).
- The completed state, Done, and Restart, in the app or from notifications (I13 to I17).
- A message for an ignored action. The app opens and shows its normal state.
- Changing the notification text, sound, or category.

### Affected components

- `ios/FocusTimer/FocusTimer/TimerStore.swift`: `cycleID` in `TimerState`, ID creation on Focus start and removal at cycle end, the repair rule, version 2 and the 1 → 2 migration step, and ID validation for the notification action.
- `ios/FocusTimer/FocusTimer/NotificationScheduler.swift`: `cycleID` parameter on `scheduleCompletion`, the `userInfo` key, and the action check.
- `ios/FocusTimer/FocusTimer/FocusTimerApp.swift`: pass the action's `cycleID` from `userInfo` to `TimerStore`; use the `startBreakAction` constant instead of the string literal.
- `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift`, `TestDoubles.swift`: the recording scheduler records the ID; new and updated tests. Existing tests that expect `scheduleCompletion` calls, or that seed or assert version 1, are updated for the cycle ID and version 2.
- `ContentView.swift`: no change expected.
- Docs after verification: [mission](../mission.md) baseline and invariants, [tech stack](../tech-stack.md) persistence row and gap note.

### Invariants to preserve

- A single authoritative timer state in `TimerStore`; the cycle ID is part of that state, not a second source of truth.
- Explicit Break confirmation: only a matching OK or the in-app Start Break starts Break. A migration, a repair, or an ignored action never does.
- Local persistence through the injected `KeyValueStore`.
- Deadline-based recovery: migrated and repaired running states keep their absolute deadlines and reconcile as before.

## Plan

1. **Cycle identity in the state**
   - [x] Add `cycleID` to `TimerState`. Create it when Focus starts, keep it through waiting and Break, and remove it at Break completion and Cancel.
   - [x] Extend `repaired`: remove an ID from idle, and add a fresh ID to an active phase that has none.
2. **Schema version 2**
   - [x] Set `currentSchemaVersion` to 2 and add the 1 → 2 step that adds an ID to a saved active state.
3. **Notifications and the action**
   - [x] Pass the cycle ID to `scheduleCompletion` and put it in `userInfo`.
   - [x] In the delegate, read `cycleID` from `userInfo` and call `TimerStore`, which reconciles and then starts Break only when the ID matches the current cycle and the phase is waiting for confirmation.
4. **Tests** (Swift Testing)
   - [x] Focus start creates an ID; Break keeps it; Break completion and Cancel remove it; the next Focus gets a different ID.
   - [x] A matching OK starts Break, including when the Focus deadline passed while suspended.
   - [x] An OK from an earlier cycle, with no ID, or with an unreadable ID does nothing: phase, ID, and saved state unchanged, and no notification scheduled.
   - [x] A duplicate OK after Break started does nothing.
   - [x] Scheduled Focus and Break completions carry the current cycle ID.
   - [x] Migration: version 1 records in each active state get an ID, keep their timer, are saved as version 2, and show no notice; idle gets none. Version 0 records migrate through both steps.
   - [x] Repair: a version 2 active state without an ID gets one and shows the notice; idle with an ID loses it.
   - [x] Existing I06 to I09 tests pass, updated for version 2 where they seed or assert the version.
5. **Docs**
   - [x] Record results here. Update the mission's baseline and invariants and the tech-stack persistence row and gap note (cycle identity exists; provenance is validated; delivered-alert cleanup remains for I11).

## Validation

### Agent-run

Run after the Swift changes. Toolchain checks per `AGENTS.md` (`xcode-select -p`, `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list`). Then, from the repository root, on iPhone 17 Pro (iOS 26.5), not the user's simulator:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath /tmp/FocusTimerTests-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
```

Record `totalTestCount`, `passedTests`, `failedTests`, and expected failures from `xcrun xcresulttool get test-results summary --path <result bundle>`. Expected: the 64-function I09 baseline plus the new tests, all passing except the one I12 known issue (`pauseAtExpiryCompletesInsteadOfAddingTime`).

### User-reported (Xcode)

- Product > Test (Cmd+U) passes with the same count.
- **Upgrade check** (iPhone 18 Pro Max, iOS 27.0): with version 1 data on the simulator (it holds a running or paused Focus or default idle data from I09), run this branch. The app keeps the same timer. The agent reads the container preferences and confirms `schemaVersion` 2 and a `cycleID` in the state when the phase is active.
- **Stale-alert check** (same simulator, notifications allowed, Focus set to 1 min):
  1. Start Focus and send the app to the background. Let the Focus alert appear; do not tap it.
  2. Open the app from the home screen. It waits for Break confirmation. Press Cancel, then Start a new Focus.
  3. Open Notification Center and tap OK on the old alert. Expected: the app opens and the new Focus keeps running; Break does not start.
  4. Control: let the new Focus alert appear and tap its OK. Expected: Break starts.
  5. Duplicate: if the same alert can be acted on again, tap it again. Expected: nothing changes.

### Remains unverified

- Removal of the old delivered alert after Cancel or a new cycle (I11); the old alert stays in Notification Center during this check.
- Other deferred OS rows from I02 (S1 to S3, the remaining N rows), and behavior on a physical device.

## Results

### Agent-run (2026-10-26)

- Toolchain: `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; Xcode 27.1; destination iPhone 17 Pro, iOS 26.5 (the user's iPhone 18 Pro Max was not used).
- First run (`/tmp/FocusTimerTests-20261026-193927.xcresult`): build error. The 1 → 2 migration step referenced `Self.stateKey` inside a stored property initializer; fixed by naming `TimerStore.stateKey`.
- Final run (`/tmp/FocusTimerTests-20261026-193947.xcresult`): `** TEST SUCCEEDED **`. `xcresulttool get test-results summary`: result Passed, `totalTestCount` 80, `passedTests` 79, `failedTests` 0, `skippedTests` 0, `expectedFailures` 1 (`pauseAtExpiryCompletesInsteadOfAddingTime`, I12). That is the 64 I09 functions plus 16 new `TimerStoreCycleTests` functions.
- Build results: no compiler warnings.

### Implementation notes

- Existing transition, invariant, and migration tests compare timing with `TimerState.ignoringCycle` (a test-only helper in `TestDoubles.swift`) where they build an expected active state without an ID. Idle comparisons still use full equality, so they check that the ID is removed.
- Tests that seed records at the current version now include a cycle ID for active states; without one, the new repair rule correctly adds it and shows the notice.
- `unversionedRecordsKeepTheirValues` now expects the 1 → 2 step to save the state with an added ID for active fixtures.
- `RecordingNotificationScheduler` records the cycle ID of each `schedule` call in `scheduledCycleIDs`; the `Call` enum is unchanged.
- The config, state, and version keys became `static`, so the migration step can read the state key.

### User-reported

- 2026-10-26, Cmd+U in Xcode 27.1 (iPhone 18 Pro Max simulator, iOS 27.0): the user reported the tests done and correct (all passed apart from the I12 known issue). The exact count was not stated.
- 2026-10-26, upgrade check: the user ran this branch from Xcode over the version 1 data recorded below and reported it done. Afterwards, with the app stopped, the agent read the container preferences: `schemaVersion` = `2`, `config` unchanged (`{"durationBSeconds":60,"durationASeconds":60}`), and `state` = `{"paused":false,"cycleID":"30AF21DA-5D5F-48B7-8D60-6C2B97630EF0","phase":"waitingForAConfirm"}`, the same phase with a cycle ID added.

### ToDo (deferred by the user, 2026-10-26)

- [ ] **Stale-alert check** (see [User-reported (Xcode)](#user-reported-xcode), steps 1 to 5): tap OK on a delivered alert from an earlier cycle after Cancel and a new Focus, and confirm Break does not start; then confirm the current alert's OK starts Break and a repeated OK does nothing. Until it is run, the roadmap exit check ("an old Focus notification cannot start Break in a newer cycle") is verified by unit tests (`actionFromAnEarlierCycleCannotStartBreak`, `actionWithoutOrWithUnknownIDIsIgnored`, `duplicateActionAfterBreakStartedDoesNothing`) and the `userInfo` parsing test, not by a real notification tap.

### Upgrade check, before (2026-10-26)

- The agent read the container preferences on iPhone 18 Pro Max (iOS 27.0) with the app stopped: `config` = `{"durationBSeconds":60,"durationASeconds":60}`, `state` = `{"paused":false,"phase":"waitingForAConfirm"}`, `schemaVersion` = `1`. This is version 1 data in an active phase (waiting for Break) with no cycle ID.
