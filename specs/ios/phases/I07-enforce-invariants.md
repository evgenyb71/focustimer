# I07 Align and enforce configuration and state invariants

Status: verified (2026-10-20): 48 test functions (47 passed, 1 expected failure owned by I12), agent-run with counts from the result bundle (iPhone 17 Pro, iOS 26.5); user-reported Cmd+U and simulator check of the correction notice (iPhone 18 Pro Max, iOS 27.0). Commit `103463e`, merged to `main` as `627f7d5` and pushed. Implements roadmap phase I07, "Align and enforce configuration/state invariants". Branch `feat/I07-enforce-invariants`.

Context: [roadmap](../roadmap.md), [mission](../mission.md), [tech stack](../tech-stack.md), previous phase [I06](I06-baseline-transition-tests.md).

Roadmap exit check: test invalid ranges, missing deadlines, impossible paused states; retain agreed minute rules.

## Requirements

### Scope

Successfully decoded `config` and `state` records are validated and repaired when `TimerStore` loads them. Configuration is also enforced when Focus starts. The store and the UI share one definition of the duration bounds. A short status message tells the user when saved data was corrected.

### Decisions (user, 2026-10-20)

- **Separate from I09.** I07 only handles records that decode successfully but break the invariants. Undecodable, partial, or unsupported records stay in [I09](../roadmap.md). There is no schema version (I08).
- **Durations: round, then clamp each value.** Each stored duration is rounded to the nearest whole minute (half rounds up). It is then clamped to its bounds: Focus 1–240 min (60–14,400 s), Break 1–120 min (60–7,200 s). A valid duration is kept even when the other one is repaired. Examples: 0 s → 1 min, 20 s → 1 min, 90 s → 2 min, 999 min → 240 min for Focus.
- **State: repair stray fields first, idle when a required field is missing.**

  | Saved phase / pause flag | Required | Repair of stray fields | When the required field is missing or invalid |
  | --- | --- | --- | --- |
  | `idle`, `waitingForAConfirm` | none | Remove the deadline and remaining time, and set paused to false | — |
  | `runningA`/`runningB`, not paused | deadline | Remove the remaining time | Fall back to idle |
  | `runningA`/`runningB`, paused | remaining time > 0 | Remove the deadline | **Treat as expired**: Focus enters waiting for Break confirmation, Break returns to idle |

  Configuration is kept in every case. After repair, normal deadline reconciliation runs, so a valid running state whose deadline has passed completes as it does today.
- **UI message.** When load repaired the configuration, the state, or both, the status line shows one short correction message. It is cleared by the next Start, Start Break, Pause, Resume, or Cancel. The message does not block any action.

### Agent decisions within the user's choices (open to revision)

- Repaired configuration and state are persisted right after load, so the store matches what the app shows.
- If repair moves the timer to idle or to waiting, all pending completions are cancelled. Waiting never needs a pending Focus alert, because the user confirms Break in the app.
- `startFocus` clamps the in-memory configuration with the same rule before persisting it. This replaces the current "at least one second" error path, which then becomes unreachable and is removed.
- The duration bounds become static constants on `TimerStore.Configuration`, for example `focusRange` and `breakRange`. `ContentView` uses those constants in place of its literal `60...(240 * 60)` and `60...(120 * 60)`.
- With the one-second error gone, `errorMessage` would only hold the correction notice, so it is renamed `noticeMessage`. The notice text is `TimerStore.repairNotice` ("Saved timer data was corrected."). `ContentView` only reads `statusMessage`, so it needs no change for this.
- The I06 transition fixture's `breakSeconds` changes from 30 to 60, because 30 s is now below the minimum and `startFocus` would clamp it. All I06 assertions take the value as a parameter, so none of them change.

### Non-goals

- Decode failures, missing keys, and unknown phase values (I09). Schema versioning and migration (I08).
- Pausing at or after expiry during a live session. The `withKnownIssue` test `pauseAtExpiryCompletesInsteadOfAddingTime` stays owned by I12. "Treat as expired" here applies only to saved paused states loaded with no positive remaining time.
- Clock changes, and deadlines or remaining time longer than the configured duration (I12).
- Cycle identity, stale notification actions, and delivered-notification cleanup (I10, I11). Completed state (I13).
- Visual redesign beyond the status-line text (I23, I24).

### Affected components

- `ios/FocusTimer/FocusTimer/TimerStore.swift`: bounds constants, configuration normalization, state repair on load, repair message, `startFocus` clamp.
- `ios/FocusTimer/FocusTimer/ContentView.swift`: stepper ranges read the shared constants. The status line already shows `statusMessage`.
- `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift`: new invariant tests. `TestDoubles.swift` changes only if a helper for seeding raw records is needed.

### Invariants to preserve

A single authoritative timer state in `TimerStore`, explicit Break confirmation (repair never starts Break), local persistence in the injected `KeyValueStore`, and deadline-based recovery for valid running phases.

## Plan

1. **Bounds and configuration normalization**
   - [x] Add the Focus and Break bounds as shared constants, and a pure normalization (round to the nearest minute, then clamp) on `Configuration`.
   - [x] Normalize the configuration on load and persist it if it changed. Apply the same rule in `startFocus`, and remove the unreachable one-second error.
   - [x] Point the `ContentView` stepper ranges at the constants.
2. **State repair on load**
   - [x] Add a pure repair function implementing the table above. It returns the repaired state and whether anything changed.
   - [x] Run it in `init` before `reconcileWithCurrentTime()`. Persist the result, and cancel pending completions when the phase changed to idle or waiting.
3. **Repair message**
   - [x] Expose the correction message through `statusMessage`, and clear it on Start, Start Break, Pause, Resume, and Cancel.
4. **Tests** (Swift Testing, seeding raw `config`/`state` data in `InMemoryStore` before constructing `TimerStore`)
   - [x] Durations: below the minimum, above each maximum, non-whole minutes (20 s, 90 s, 150 s), and in-range values unchanged. Each value is repaired independently, and the repaired config is persisted.
   - [x] `startFocus` with an out-of-range in-memory configuration runs with clamped durations.
   - [x] Missing deadline on an unpaused running Focus or Break → idle, with config retained and completions cancelled.
   - [x] Paused Focus or Break with nil, zero, or negative remaining time: Focus → waiting, Break → idle. Break never starts.
   - [x] Stray fields are stripped: deadline or remaining time on idle or waiting, remaining time on unpaused running, deadline on paused running, and paused on idle or waiting.
   - [x] Valid saved states load unchanged with no message, and the existing I06 relaunch tests still pass.
   - [x] The message appears after a repair and clears after the next action.
5. **Docs**
   - [x] Record results here. Update the mission's "store currently validates only a one-second lower bound" line and the tech-stack gap note ("not semantically validated") to match the delivered behavior.

## Validation

### Agent-run

Toolchain checks per `AGENTS.md` (`xcode-select -p`, `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list`). Then, from the repository root, on iPhone 17 Pro (iOS 26.5), not the user's simulator:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath /tmp/FocusTimerTests-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
```

Record `totalTestCount`, `passedTests`, `failedTests`, and expected failures from `xcrun xcresulttool get test-results summary --path <result bundle>`. Expected: the 36-function I06 baseline plus the new tests, all passing except the one I12 known issue.

### User-reported (Xcode)

- Product > Test (Cmd+U) passes with the same count.
- One look in the simulator: the correction message appears after a repair and clears on the next action. Method (no debug build needed): stop FocusTimer in Xcode, write a 30-second Focus duration into the app's saved configuration, then run again:

  ```sh
  xcrun simctl spawn 'iPhone 18 Pro Max' defaults write "$(xcrun simctl get_app_container 'iPhone 18 Pro Max' com.ebochkarev.FocusTimer data)/Library/Preferences/com.ebochkarev.FocusTimer" config -data 7b226475726174696f6e415365636f6e6473223a33302c226475726174696f6e425365636f6e6473223a36307d
  ```

  The full container path is required. The first attempt wrote to the bare domain (`defaults write com.ebochkarev.FocusTimer …`), which lands in the simulator's shared `Library/Preferences`, not the sandboxed app's container. The app therefore loaded its valid 60/60 config and correctly showed no message.

  Xcode moves the app's data container on each Run or Test (the path changed three times during this check), so seed only after stopping the app. Then launch it from the simulator home screen, not with Cmd+R.

  The hex is `{"durationASeconds":30,"durationBSeconds":60}`. Expected: the status line reads "Saved timer data was corrected.", Focus shows 1 min, and the message is replaced by the normal text after Start or Cancel.

### Remains unverified

OS notification delivery and removal, real suspension and relaunch, and corrupt or undecodable records (I09).

## Results

### Agent-run (2026-10-20)

- Toolchain: `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; Xcode 27.0 (27A266a); iOS Simulator SDK 27.0; destination iPhone 17 Pro, iOS 26.5 (the user's booted iPhone 18 Pro Max, iOS 27.0, was not used).
- `xcodebuild … test` (command above), result bundle `/tmp/FocusTimerTests-20261020-165545.xcresult`: `** TEST SUCCEEDED **`.
- `xcrun xcresulttool get test-results summary`: result Passed, `totalTestCount` 48, `passedTests` 47, `failedTests` 0, `skippedTests` 0, `expectedFailures` 1 (`pauseAtExpiryCompletesInsteadOfAddingTime`, I12). That is 36 I06 functions plus 12 new `TimerStoreInvariantTests` functions.
- `xcresulttool get build-results`: 0 warnings, 0 errors. `git diff --check`: clean.

### User-reported

- 2026-10-20, Cmd+U in Xcode (iPhone 18 Pro Max simulator, iOS 27.0): 48 tests passed, as reported by the user.
- 2026-10-20, simulator check of the notice (iPhone 18 Pro Max, iOS 27.0): the agent seeded a 30 s Focus duration into the app's container preferences and confirmed it on disk. The user launched the app from the home screen and saw "Saved timer data was corrected."; the message cleared after Start. The first two attempts did not reach the app: one went to the wrong preferences domain, and in the other the container moved after an Xcode run (see the method above).

### Limitations

- The repair runs only at load and only on records that decode. Undecodable or unknown-phase records still fall back silently to defaults (I09).
- Remaining time or deadlines longer than the configured duration are not checked (I12).
- Pausing at expiry during a live session still adds 1 s (known issue, I12).
