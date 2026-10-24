# I09 Recover corrupt, partial, and unsupported saved records

Status: verified, pending commit (2026-10-24): implemented; 64 test functions pass (63 passed, 1 expected failure for I12), agent-run on iPhone 17 Pro iOS 26.5. User-reported Cmd+U and both seeded relaunch cases passed. Implements roadmap phase I09, "Recover corrupt/partial/unsupported saved records". Branch `feat/I09-recover-saved-records`.

Context: [roadmap](../roadmap.md), [mission](../mission.md), [tech stack](../tech-stack.md), previous phase [I08](I08-schema-versioning.md) (its handoff lists the open questions answered below).

Roadmap exit check: safe idle fallback, valid config preserved, relaunch remains usable.

## Requirements

### Scope

All four cases left open by I08:

1. **Newer, negative, or undecodable `schemaVersion`.** Today the app uses defaults in memory and writes nothing at launch, and a later save such as Start overwrites `config` and `state` but keeps the odd version, so the next launch ignores them again.
2. **One bad record.** When only `config` or only `state` fails to decode, the other is kept. Each already falls back independently; this phase confirms it with tests.
3. **Unknown or wrong-typed values inside a readable record** (for example an unknown `phase` string, or durations stored as text).
4. **The Start-overwrite limitation** from I08 (case 1).

### Decisions (user, 2026-10-24)

- **Newer or unreadable version: fix the overwrite.** Keep I08 launch behavior: idle defaults in memory, nothing written at launch. The first save afterwards (for example Start) also writes `schemaVersion = 1`, so the next launch reads the records the app wrote.
- **No best-effort decoding for an unknown version.** A newer-format `config` is not read, even if it would decode; defaults are used.
- **Notice:** every recovery case reuses the I07 correction notice ("Saved timer data was corrected."). No new text.
- **No backup:** unreadable data is replaced without copying it to backup keys.
- **Per-record fallback for bad values:** a record that fails to decode becomes defaults (`config`) or idle (`state`) as a whole. No per-field lenient decoding. A record that decodes is then normalized and repaired as in I07.
- **Validation:** agent-run unit tests, user-reported Cmd+U, and a seeded relaunch check on the iPhone 18 Pro Max simulator.

### Agent decisions within the user's choices (open to revision)

- **What counts as unreadable:** a key that is present but fails to decode. A missing key (fresh install, or a record never saved) is not corruption and shows no notice, as today.
- **Notice for a newer or unreadable version** appears at launch even though nothing is written, because the stored records were ignored.
- **Corrupt records at the current version are replaced at launch,** like I07 repairs: the replacement (default config or idle state) is saved and the notice is shown. A version-0 record that fails to decode is also replaced after migration.
- **A recovered running state cancels pending completion notifications,** as the I07 repair does when the phase changes, so an old alert cannot fire for a timer the app no longer has.
- **Writing version 1 on the first save:** done in the same place that persists `config` and `state`, only when the stored version is not the current one. Normal saves at version 1 do not rewrite the version.
- **The notice clears as it does today** (I07 behavior); I09 does not change when it is dismissed.

### Non-goals

- Per-field lenient decoding, best-effort reading of newer formats, backups of unreadable data, or a new notice text.
- Changing the format of `config` or `state`, cycle identity (I10), the completed state (I13), and expiry/clock-edge fixes (I12).
- Delivered-notification cleanup (I11). Notification permission guidance (I18).
- Changing the I07 normalization or repair rules.

### Affected components

- `ios/FocusTimer/FocusTimer/TimerStore.swift`: launch load distinguishing missing from unreadable records, notice and persistence for recovery, version write on the first save after an unsupported version.
- `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift`, `TestDoubles.swift`: recovery tests; `InMemoryStore.writtenKeys` already records writes.
- `ContentView.swift`: no change expected (the notice already shows through `statusMessage`).
- Docs when behavior changes: [mission](../mission.md) baseline and [tech stack](../tech-stack.md) gap note.

### Invariants to preserve

A single authoritative timer state in `TimerStore`; recovery never starts Break or any phase (a recovered state is idle or waiting-for-confirm per the I07 repair rules, never running without a deadline); local persistence through the injected `KeyValueStore`; deadline-based recovery for valid running states, which keep their absolute deadline and reconcile as before.

## Plan

1. **Load path**
   - [x] Separate "key missing" from "key present but undecodable" for `config` and `state` in `TimerStore.decode`'s callers.
   - [x] Show the I07 notice, persist the replacement, and cancel pending completions when an unreadable record is replaced at the current or a migrated version.
   - [x] For a newer, negative, or undecodable `schemaVersion`: keep defaults in memory and write nothing at launch, but set the I07 notice.
2. **Save path**
   - [x] When the stored version is unsupported, the first save of `config` or `state` also writes `schemaVersion = 1`. Later saves do not rewrite it.
3. **Tests** (Swift Testing; seed raw bytes in `InMemoryStore` before constructing `TimerStore`)
   - [x] Newer version (2), negative version, and undecodable version bytes: idle defaults in memory, nothing written at launch, notice shown, stored data untouched.
   - [x] After one of those, Start writes `config`, `state`, and `schemaVersion = 1`; a new `TimerStore` on the same store loads the saved Focus with no notice.
   - [x] Corrupt `state` with valid non-default `config`: config kept, state idle, notice shown, replacement saved.
   - [x] Corrupt `config` with valid running `state`: defaults for config, running state kept with its deadline, notice shown.
   - [x] Both records corrupt: defaults and idle, usable (Start works), notice shown.
   - [x] Unknown `phase` string and durations stored as text: the whole record falls back, other record kept, notice shown.
   - [x] A corrupt state that replaces a running phase cancels pending completion notifications (recording scheduler).
   - [x] Missing keys on a fresh install: no notice (regression); valid version-1 data loads byte-for-byte unchanged with no writes (regression).
   - [x] Existing I06 to I08 tests still pass.
4. **Docs**
   - [x] Record results here. Update the tech-stack persistence/gap note and the mission persistence line. Do not edit the roadmap table until the phase is verified and pushed.

## Validation

### Agent-run

Run only after Swift changes. Toolchain checks per `AGENTS.md` (`xcode-select -p`, `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list`). Then, from the repository root, on iPhone 17 Pro (iOS 26.5), not the user's simulator:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath /tmp/FocusTimerTests-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
```

Record `totalTestCount`, `passedTests`, `failedTests`, and expected failures from `xcrun xcresulttool get test-results summary --path <result bundle>`. Expected: the 55-function I08 baseline plus the new tests, all passing except the one I12 known issue (`pauseAtExpiryCompletesInsteadOfAddingTime`).

### User-reported (Xcode)

- Product > Test (Cmd+U) passes with the same count.
- **Seeded relaunch check** (iPhone 18 Pro Max, iOS 27.0), with the app stopped:
  1. The agent seeds corrupt records in the app's container preferences (see [I07](I07-enforce-invariants.md#user-reported-xcode); container path, not the bare domain, and only while the app is stopped): for example valid `config` (Focus 25, Break 5) with an unreadable `state`, then a case with `schemaVersion` 2.
  2. The user runs the app from Xcode. Expected: the app opens idle, shows the correction notice, and keeps Focus 25 and Break 5 in the first case (defaults in the second); Start works.
  3. The agent reads the container preferences again and confirms that unreadable records were replaced (first case) or left untouched until Start, after which `schemaVersion` is 1 (second case).
  4. Relaunch: the app opens with the saved state and no notice.

### Remains unverified

OS notification delivery and real suspension (S1 to S3, N1 to N8 from I02). Corruption produced by a real interrupted write or a newer app build, since only seeded records are used.

## Results

### Agent-run (2026-10-24)

- Toolchain: `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; Xcode 27.1 (27A9275), upgraded from 27.0 the day before; only iOS 27.1 SDK installed; iOS 26.5 runtime and iPhone 17 Pro still available (the user's iPhone 18 Pro Max was not used).
- First run (`/tmp/FocusTimerTests-20261024-140016.xcresult`): 64 tests, 2 failed, both test bugs: JSON bytes compared although key order varies, and the seeded version write counted. Fixed in the tests only. The run took about 10 minutes because the Xcode upgrade invalidated the build cache.
- Final run (`/tmp/FocusTimerTests-20261024-141126.xcresult`): `** TEST SUCCEEDED **`. `xcresulttool get test-results summary`: result Passed, `totalTestCount` 64, `passedTests` 63, `failedTests` 0, `skippedTests` 0, `expectedFailures` 1 (`pauseAtExpiryCompletesInsteadOfAddingTime`, I12). That is the 55 I08 functions plus 9 new `TimerStoreRecoveryTests` functions.
- Build results: no warnings other than the AppIntents metadata note. 

### User-reported

- 2026-10-24, Cmd+U in Xcode 27.1 (iPhone 18 Pro Max simulator, iOS 27.0): 64 tests in 5 suites passed with 1 known issue (I12), as reported by the user.
- 2026-10-24, seeded relaunch, case 1 (valid `config` 25/5, `schemaVersion` 1, `state` = `not json`): launched from the home screen, the app opened as expected (idle, 25/5, correction notice) and Start worked. Afterwards the agent read the container preferences: `config` 25/5, `schemaVersion` 1, and `state` was no longer `not json` (a paused Focus after the user's Start and pause).
- 2026-10-24, seeded relaunch, case 2 (`schemaVersion` 2, `config` 25/5, `state` paused Focus 900 s): the app opened as expected (defaults, notice). After the user pressed Start and stopped the app, the agent read: `schemaVersion` 1, `config` = 60/60 s defaults, `state` = running Focus with a deadline. Both records and the version were replaced by the first save.
- Method note: the first seeding attempt wrote the plist file directly while the simulator's preference service held old values, so the app showed the old paused Focus and did not exercise recovery; the cases above were seeded with `xcrun simctl spawn <device> defaults write` on the container path with the app stopped.

### Limitations

- Plan step 4 of the relaunch check (relaunch again and see the saved state with no notice) was not run on the device; it is covered by unit tests (`firstSaveAfterUnsupportedVersionWritesCurrentVersion`, `bothRecordsCorruptStillStarts`).
- Only seeded records were used, not corruption from a real interrupted write or a newer app build.
