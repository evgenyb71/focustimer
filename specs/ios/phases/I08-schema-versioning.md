# I08 Schema versioning and migration of current records

Status: verified (2026-10-20): 55 test functions (54 passed, 1 expected failure owned by I12), agent-run with counts from the result bundle (iPhone 17 Pro, iOS 26.5); user-reported Cmd+U and an upgrade check on real pre-I08 saved data (iPhone 18 Pro Max, iOS 27.0). Not yet committed. Implements roadmap phase I08, "Add schema versioning and migration of current records". Branch `feat/I08-schema-versioning`.

Context: [roadmap](../roadmap.md), [mission](../mission.md), [tech stack](../tech-stack.md), previous phase [I07](I07-enforce-invariants.md).

Roadmap exit check: fixtures from existing unversioned keys retain valid settings and timer state.

## Requirements

### Scope

Saved data gains a schema version, and `TimerStore` runs an ordered migration from the stored version to the current one before it decodes `config` and `state`. Today's unversioned records are the first migrated format. Later phases that change the saved format, such as cycle identity (I10) and the completed state (I13), add one migration step each instead of special-casing old data.

### Decisions (user, 2026-10-20)

- **One separate version key.** A new key, `schemaVersion` (an integer), covers both records. The `config` and `state` keys and their JSON stay unchanged, so builds from before I08 can still read them.
- **Version numbering.** A missing `schemaVersion` means today's unversioned format. The current format becomes version 1.
- **Write at launch.** When the stored version is older than the current one, the migration runs and the migrated records and new `schemaVersion` are saved immediately at launch. The I07 normalization and repair then run on the migrated records, as they do today.
- **Newer versions are left to I09.** If `schemaVersion` is greater than the version the app understands, I08 does what an unreadable record does today: it uses the defaults in memory. See the agent decisions below for what is written.
- **Validation:** agent-run unit tests with sample unversioned records, user-reported Cmd+U, and a user upgrade check on real saved data in the iPhone 18 Pro Max simulator.

### Agent decisions within the user's choices (open to revision)

- Moving from unversioned data to version 1 changes no record content. It only writes `schemaVersion = 1`. The step still goes through the same ordered migration path as future steps, so that path is exercised from the start.
- A fresh install, with no `config`, `state`, or `schemaVersion`, also gets `schemaVersion = 1` written at launch. Every launch then ends with a versioned store.
- For a newer, unknown version, nothing is written at launch, so the newer data is not overwritten or downgraded just by opening the app. A later save, such as Start, overwrites `config` and `state` as it would today. Whether that should happen is an I09 question.
- An unversioned record that fails to decode still falls back to defaults as today, and the version is still written. Recovering that record belongs to I09.
- The version number, the migration steps, and the key name are kept in `TimerStore.swift` next to the existing `config` and `state` keys, unless the code reads better in a small new file. No generic persistence framework.

### Implementation notes

- The version is stored as JSON-encoded `Data` through the existing `data`/`setData` methods, so the `KeyValueStore` protocol is unchanged. In UserDefaults it appears as a 1-byte data value, `1`.
- `TimerStore.currentSchemaVersion` is `nonisolated static let`, because Swift Testing evaluates test arguments outside the main actor.
- A negative or undecodable `schemaVersion` is treated like a newer one: defaults in memory, nothing written. Recovering it belongs to I09.
- `InMemoryStore` records the keys it writes (`writtenKeys`), so tests can assert that loading wrote nothing, or only the version.
- The I07 test `validRecordsLoadUnchangedWithoutNotice` now seeds `schemaVersion = 1`. Its point is that valid current-format records load untouched; without the version, loading now correctly adds it.

### Non-goals

- Recovering corrupt, partial, or unsupported (newer) records, and any message for them (I09).
- Changing the content or format of `config` or `state`, cycle identity (I10), and the completed state (I13).
- Changing the I07 normalization, repair, or correction notice. Migration alone shows no message.

### Affected components

- `ios/FocusTimer/FocusTimer/TimerStore.swift`: `schemaVersion` key, current version constant, migration step list, launch-time migration before decoding.
- `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift`: migration tests. `TestDoubles.swift` changes only if seeding the version needs a helper. `KeyValueStore` may need an integer accessor, or the version can be stored as encoded `Data` through the existing `data`/`setData` methods; prefer whichever keeps the protocol smallest.
- `ContentView.swift`: no change expected.

### Invariants to preserve

A single authoritative timer state in `TimerStore`, explicit Break confirmation (migration never starts Break), local persistence in the injected `KeyValueStore`, and deadline-based recovery for running phases: a migrated running state keeps its absolute deadline and reconciles as before.

## Plan

1. **Version key and migration path**
   - [x] Add the `schemaVersion` key, a current version of 1, and an ordered list of migration steps, starting with unversioned → 1.
   - [x] In `init`, read the stored version before decoding. If it is older, run the steps in order and save the records and the new version. If it is newer, skip migration, use defaults in memory, and write nothing.
   - [x] Keep the I07 normalization and repair running after migration.
2. **Tests** (Swift Testing; seed raw records in `InMemoryStore` before constructing `TimerStore`)
   - [x] Unversioned fixtures keep their values: valid non-default config (for example 25 and 5 min) with each state (idle, running Focus and Break with a future deadline, paused Focus and Break, waiting for Break). Settings and state load unchanged, and `schemaVersion` is saved as 1.
   - [x] An unversioned running state whose deadline passed during the upgrade reconciles as before (Focus waits for confirmation, Break returns to idle).
   - [x] A fresh install writes `schemaVersion = 1` and loads the defaults.
   - [x] Version 1 data loads with no migration writes; the stored data is byte-for-byte unchanged.
   - [x] Unversioned data that I07 would repair is migrated and then repaired, with the correction notice shown as in I07.
   - [x] A newer version (for example 2) loads the defaults in memory and leaves the stored `config`, `state`, and `schemaVersion` untouched.
   - [x] The existing I06 and I07 tests still pass. They start from an empty store, so they now also exercise the fresh-install path.
3. **Docs**
   - [x] Record results here. Update the tech-stack persistence row and gap note ("There is no schema version, migration, …") and the mission's persistence line.

## Validation

### Agent-run

Toolchain checks per `AGENTS.md` (`xcode-select -p`, `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list`). Then, from the repository root, on iPhone 17 Pro (iOS 26.5), not the user's simulator:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath /tmp/FocusTimerTests-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
```

Record `totalTestCount`, `passedTests`, `failedTests`, and expected failures from `xcrun xcresulttool get test-results summary --path <result bundle>`. Expected: the 48-function I07 baseline plus the new tests, all passing except the one I12 known issue.

### User-reported (Xcode)

- Product > Test (Cmd+U) passes with the same count.
- **Upgrade check on real saved data** (iPhone 18 Pro Max, iOS 27.0):
  1. On `main` (the pre-I08 build), set non-default durations, for example Focus 25 min and Break 5 min, start Focus, and pause it. Stop the app.
  2. The agent reads the stored `config` and `state` and confirms there is no `schemaVersion`.
  3. Switch to this branch, then Run from Xcode. The app shows the same durations and the paused Focus with the same remaining time.
  4. The agent reads the store again and confirms `schemaVersion` is 1 and `config` and `state` are unchanged.

  Read the store through the app's container preferences path, not the bare domain; see the method in [I07](I07-enforce-invariants.md#user-reported-xcode).

### Remains unverified

Newer or unsupported versions beyond keeping them intact at launch (I09). OS notification delivery and real suspension, unchanged from earlier phases.

## Results

### Agent-run (2026-10-20)

- Toolchain: `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; Xcode 27.0 (27A266a); iOS Simulator SDK 27.0; destination iPhone 17 Pro, iOS 26.5 (the user's iPhone 18 Pro Max was not used).
- First run: build error. `currentSchemaVersion` was main-actor isolated but read in test arguments; fixed with `nonisolated`.
- Second run (`/tmp/FocusTimerTests-20261020-175437.xcresult`): 55 tests, 1 failure, `validRecordsLoadUnchangedWithoutNotice`, which now saw the version written; fixed as described under the implementation notes.
- Final run (`/tmp/FocusTimerTests-20261020-175540.xcresult`): `** TEST SUCCEEDED **`. `xcresulttool get test-results summary`: result Passed, `totalTestCount` 55, `passedTests` 54, `failedTests` 0, `skippedTests` 0, `expectedFailures` 1 (`pauseAtExpiryCompletesInsteadOfAddingTime`, I12). That is the 48 I07 functions plus 7 new `TimerStoreMigrationTests` functions.
- Build results: 0 warnings, 0 errors. `git diff --check`: clean.

### User-reported

- 2026-10-20, Cmd+U in Xcode (iPhone 18 Pro Max simulator, iOS 27.0): 55 tests passed, as reported by the user.
- 2026-10-20, upgrade check steps 3 and 4: the user ran this branch from Xcode over the pre-I08 data recorded above. The app showed Focus 25 min and Break 5 min with Focus paused. The agent then read the container preferences: the keys were `config`, `state`, and `schemaVersion`; `schemaVersion` = `1`; `config` = `{"durationBSeconds":300,"durationASeconds":1500}` and `state` = `{"remainingSeconds":1494,"paused":true,"phase":"runningA"}`, the same values as before the upgrade.

### Limitations

- With a newer or unreadable version, a later save such as Start overwrites `config` and `state` but leaves the newer `schemaVersion`. The next launch then ignores those records again. Recovering this case belongs to I09.

### Upgrade check, before (2026-10-20)

- The user ran the pre-I08 build: the branch was at `8845216`, the same as `main`, with only this spec added. They set Focus 25 min and Break 5 min, started Focus, paused it, and stopped the app.
- The agent read the container preferences on iPhone 18 Pro Max (iOS 27.0). The keys present were `config` and `state` only, with no `schemaVersion`. `config` = `{"durationBSeconds":300,"durationASeconds":1500}`; `state` = `{"remainingSeconds":1494,"paused":true,"phase":"runningA"}`.

## Handoff for the next session (2026-10-20)

For any agent (Claude Code, Codex) picking up the iOS work.

- **State:** I01 to I08 are verified. I08 was committed together with this handoff on `feat/I08-schema-versioning`, merged into `main` with `--no-ff`, and pushed; before that merge, `main` was at `8845216`. `$update-changelog` was run for I08 before merging, and the changelog also covers the earlier I07 roadmap and handoff commits.
- **Next step:**
  1. On a short `chore/` branch, move the I08 roadmap row to the completed table with the merge commit, and replace "Not yet committed." in this spec's status line with the commit and merge.
  2. Then start I09 with `$start-phase` / `/start-phase`; no I09 spec exists yet.
- **Decided in chat:** everything decided for I08 is recorded in this spec.
- **Open questions for I09** (recover corrupt, partial, or unsupported saved records; exit check: safe idle fallback, valid config preserved, relaunch remains usable):
  - **Newer or unreadable `schemaVersion`:** keep today's behavior (defaults in memory, nothing written at launch), or reset the version and records? Should later saves be allowed to overwrite the records while the newer version stays?
  - **One bad record:** when only `state` or only `config` fails to decode, keep the readable one. Today each falls back independently, which already keeps a valid config when only the state is corrupt. Confirm this and test it.
  - **Unknown values inside a readable record:** for example an unknown `phase` string. Today the whole record fails to decode.
  - **Message:** whether recovery reuses the I07 correction notice or gets its own text.
  - **Unreadable data:** whether to back it up before overwriting.
- **Known issues:**
  - `pauseAtExpiryCompletesInsteadOfAddingTime` is wrapped in `withKnownIssue` for I12; do not remove the marker unless fixing that behavior.
  - Remaining time or deadlines longer than the configured duration are not checked (I12).
  - With a newer or unreadable version, a save such as Start overwrites `config` and `state` but keeps the newer version, so the next launch ignores them again (I09).
- **Test baseline:** `/tmp/FocusTimerTests-20261020-175540.xcresult` has 55 test functions: 54 passed, 0 failed, 1 expected failure. That is the 48 from I07 plus 7 `TimerStoreMigrationTests`, all in `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift`. The user reported 55 passing with Cmd+U.
- **Environment:**
  - `xcode-select` points at full Xcode 27.0 (27A266a).
  - Agents run tests on iPhone 17 Pro (iOS 26.5), which is shut down. The user's device is the iPhone 18 Pro Max (iOS 27.0), still booted; leave it alone.
  - That simulator now holds versioned data: Focus 25 min, Break 5 min, Focus paused with 1494 s left, `schemaVersion` 1.
  - Agent build output lives in `/tmp/FocusTimerDerivedData` (171 MB) and seven `/tmp/FocusTimerTests-*.xcresult` bundles (105 MB). It is untracked and not deleted.
- **Manual simulator checks that need saved data:** read or seed the app's container preferences (`xcrun simctl get_app_container … data` plus `/Library/Preferences/com.ebochkarev.FocusTimer`), not the bare `defaults` domain. Do it only while the app is stopped; Xcode moves the data container on each Run or Test. See [I07](I07-enforce-invariants.md#user-reported-xcode).
- **Still deferred from I02:** suspension and OS notification rows S1 to S3 and N1 to N8 have not been run.
