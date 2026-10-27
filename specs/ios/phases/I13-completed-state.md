# I13 Add and persist the completed state

Status: verified (2026-10-27): 135 test functions, all passed, 0 expected failures, agent-run on iPhone 17 Pro iOS 26.5; user-reported Cmd+U as expected and all steps of the upgrade and relaunch check on the iPhone 18 Pro Max (iOS 27.0). The agent did not read the stored data during steps 2 and 5; it read version 2 before and version 3 after. Implements roadmap phase I13, "Add and persist the completed state". Branch `feat/I13-completed-state`.

Context: [roadmap](../roadmap.md), [mission](../mission.md), [tech stack](../tech-stack.md), previous phases [I24](I24-end-states.md) (planned before this phase; it supplies the Break-end screen) and [I12](I12-expiry-clock-edges.md).

Roadmap exit check: Break expiry enters completed once; migration and relaunch restore it with no active deadline.

## Requirements

### Scope

Today a finished Break returns to idle. Since I24 an unsaved `breakJustFinished` flag shows the Break-end screen ("Cycle complete") until the next action or a relaunch. This phase adds a durable `completed` phase: Break expiry enters it, it is saved and restored on relaunch, and it replaces the I24 flag while keeping the same screen. Done (I14) and Restart (I15) come later; until then the user leaves completed with the existing controls.

### Decisions (user)

Taken on 2026-10-27, while I13 planning was paused for I24, and recorded in the [I24 spec](I24-end-states.md#notes-carried-to-i13-user-decisions-2026-10-27):

- **Completed keeps the cycle ID** of the finished cycle, so I16 can validate a Break alert against it. Only idle has no cycle ID.
- **Schema version 3 with a no-op 2 → 3 step.** Builds before I13 then treat data that may contain `completed` as a newer version (I09) and leave it alone, instead of failing to decode the state.
- **The delivered Break alert stays while completed.** It is the current alert, like the Focus alert while waiting for Break. It is removed when the user leaves completed. This changes the I11 launch and activation rule for this state.

Taken on 2026-10-27 for this spec:

- **Leaving completed before I14 and I15:** the I24 Break-end screen stays as it is. Start Focus starts a new Focus with a new cycle ID; Cancel (×) returns to idle. I14 and I15 turn these into real Done and Restart.
- **Durations are editable while completed** and the app stays completed; Start Focus uses the edited durations. Unlike the I24 flag, editing no longer clears the end screen.
- **Validation:** agent unit tests, an agent read of the user's simulator data after the 2 → 3 upgrade, user-reported Cmd+U, and a manual relaunch and Notification Center check.

### Agent decisions within the user's choices (open to revision)

- **Model:** `Phase.completed` (raw value `"completed"`). The mission invariant becomes: idle, waiting, and completed have no deadline and no paused time; every phase except idle has a cycle ID.
- **Entering completed:** only Break completion (`handlePhaseCompletion()` for `runningB`) enters it, whether reconciled in the app, on activation, or at launch. It happens once: completed is not a running phase, so later reconciles do nothing. A forward clock jump during Break also ends in completed.
- **The I24 flag is removed.** `endState` maps `.completed` to `.breakComplete`; `ContentView` needs no change for the Break-end screen. The Break-end screen now survives a relaunch.
- **Controls in completed:** `canStart` and `canEditDurations` include completed; `canPause` does not. `startFocus()` accepts idle or completed. The primary button reads "Start Focus" (from I24). Cancel works as from any state.
- **Repair (I07 rules):** a saved completed state with stray deadline or paused fields has them removed; a completed state without a cycle ID gets a fresh one. Both are saved and show the correction notice. A completed state is never turned into a running one.
- **Alert cleanup:** launch and activation keep the delivered Break alert while completed and remove the Focus alert. Starting a Focus and Cancel already remove all delivered alerts (I11), which covers leaving completed. Break completion still cancels the pending Break request only.
- **Notification action:** the Focus alert's OK does nothing in completed (the phase is not waiting), as today for idle.
- **Migration 2 → 3** changes no records; only the version is written. Existing idle records stay idle (a cycle that finished before the upgrade is not turned into completed).
- **Repair of a paused Break without time left** (added during implementation): the I07 rule treated it as expired and returned to idle; it now enters completed with its cycle ID, consistent with Break expiry. Focus is unchanged (waits for confirmation).

### Non-goals

- Done (I14) and Restart (I15) as their own actions or buttons; notification Done and Restart (I16, I17).
- The launch-state policy for the other states (I22); this phase only restores completed.
- Visual changes; the I24 Break-end screen is reused as is.
- Changing how a finished cycle before the upgrade is shown (it stays idle).

### Affected components

- `ios/FocusTimer/FocusTimer/TimerStore.swift`: `Phase.completed`, Break completion, controls and `startFocus()`, `endState` and status text, repair rules, schema version 3 and its migration step, removal of `breakJustFinished` and its `didSet`, alert cleanup rule.
- `ios/FocusTimer/FocusTimer/NotificationScheduler.swift`: the `switch` statements over `Phase` gain the `completed` case (no alert is scheduled or cancelled for it).
- `ios/FocusTimer/FocusTimer/ContentView.swift`: no change expected beyond what the compiler requires.
- `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift`: new tests; existing tests that expect idle after Break, the I24 flag, version 2, or the I11 cleanup lists are updated where the new behavior is intended.
- Docs after verification: [mission](../mission.md) flow line, baseline, and invariants; [tech stack](../tech-stack.md) persistence row and gap note; the I24 spec's note that the flag was replaced.

### Invariants to preserve

- A single authoritative timer state in `TimerStore`; completed is a saved phase, not a view flag.
- Explicit Break confirmation: completed never leads to Break; a new cycle starts with Focus and still waits for confirmation.
- Local persistence through the injected `KeyValueStore`.
- Deadline-based recovery: running phases keep their wall-clock deadlines; completed has none.

## Plan

1. **Model and transitions**
   - [x] Add `Phase.completed`; Break completion enters it with the cycle ID and no deadline; update `canStart`, `canEditDurations`, and `startFocus()`.
   - [x] Update `statusTitle`, `statusMessage`, and `endState` for completed; remove `breakJustFinished` and its `didSet`.
   - [x] Handle `completed` in the `NotificationScheduler` switches.
2. **Persistence**
   - [x] Repair rules for completed (stray fields, missing cycle ID).
   - [x] Schema version 3 with a no-op 2 → 3 step.
3. **Alert cleanup**
   - [x] Keep the delivered Break alert on launch and activation while completed; remove the Focus alert.
4. **Tests** (Swift Testing)
   - [x] Break completion (in the app, on activation, at launch, after a forward jump) enters completed once, with the cycle ID, no deadline, and saved; repeated reconcile changes nothing.
   - [x] Relaunch in completed restores it with the Break-end screen and no notice.
   - [x] Start Focus from completed starts a new cycle with a new ID; Cancel returns to idle; both remove delivered alerts. Editing durations keeps completed, and Start Focus uses them.
   - [x] Pause and the Focus alert's OK do nothing in completed.
   - [x] Repair of completed with stray fields or no cycle ID shows the notice; version 2 records migrate to 3 unchanged; version 3 data loads without writes.
   - [x] Launch and activation in completed keep the Break alert and remove the Focus alert.
   - [x] Existing tests pass, updated where the new behavior is intended (idle → completed after Break, I24 flag tests, version numbers, cleanup lists).
5. **Docs**
   - [x] Record results here; update the mission, the tech stack, and the I24 spec note.

## Validation

### Agent-run

Run after the Swift changes. Toolchain checks per `AGENTS.md` (`xcode-select -p`, `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list`). Then, from the repository root, on iPhone 17 Pro (iOS 26.5), not the user's simulator:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath /tmp/FocusTimerTests-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
```

Record `totalTestCount`, `passedTests`, `failedTests`, and expected failures from `xcrun xcresulttool get test-results summary --path <result bundle>`. Expected: the 121-function I24 baseline plus the new tests, all passing, 0 expected failures.

### User-reported (Xcode)

- Product > Test (Cmd+U) passes; report the summary line with the count.
- **Upgrade and relaunch check** (iPhone 18 Pro Max, iOS 27.0, notifications allowed, Focus and Break at 1 min):
  1. Before running this branch, the agent reads the stored data with the app stopped (expected `schemaVersion` 2).
  2. Run this branch from Xcode. The app keeps its state. Stop it; the agent reads `schemaVersion` 3 and unchanged `config` and `state`.
  3. Start Focus, let it end, start Break, go to the home screen, and let Break end. The Break alert appears.
  4. Open the app from the home screen: "Cycle complete" shows, and the Break alert is still in Notification Center.
  5. Stop the app and open it again from the home screen: still "Cycle complete". The agent can read `state` = completed with a cycle ID and no deadline.
  6. Press Start Focus: a new Focus runs and the Break alert is gone. (Alternatively press Cancel: idle, and the alert is gone.)

### Remains unverified

- Behavior on a physical device.
- Notification Done and Restart (I16, I17).
- Other deferred OS rows from I02 (S1 to S3).

## Results

### Agent-run (2026-10-27)

- Toolchain: `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; Xcode 27.1; destination iPhone 17 Pro, iOS 26.5 (the user's iPhone 18 Pro Max was not used).
- First run (`/tmp/FocusTimerTests-20261027-214441.xcresult`): 135 tests, 13 failed. Twelve expected idle after Break, version 2, or the I11 activation list that removed the Break alert; all are intended changes. One, `unknownPhaseFallsBackWholeRecordAndKeepsConfiguration` (I09), used `"completed"` as its example of an unknown phase, which is now a real phase; its fixture now uses `"finished"`.
- Updates to existing tests (behavior intended by I13):
  - I06: `breakExpiryReturnsToIdleKeepingConfiguration`, `delayedBreakReconciliationOnlyReturnsToIdle`, `relaunchAfterBreakDeadlineReturnsToIdle` renamed to `…CompletesTheCycle…` and expect completed.
  - I07: `pausedWithoutRemainingTimeIsTreatedAsExpired` expects completed for Break.
  - I08: `unversionedRunningStateWithPassedDeadlineReconciles` expects completed for Break.
  - I10: `cycleIDLastsFromFocusStartThroughBreak` expects completed with the same cycle ID at the end; `version1ActiveStateGetsACycleIDWithoutNotice` compares with `currentSchemaVersion` instead of 2.
  - I11: `breakCompletionRemovesOnlyThePendingBreakRequest` expects completed; `activationAfterBreakEndedInTheBackgroundRemovesTheBreakAlert` renamed to `…KeepsTheBreakAlert` and no longer expects the Break alert to be removed.
  - I12: the `completed(_:)` helper returns completed for Break; `launchWithAnExtremePastDeadlineCompletesInsteadOfCrashing` expects completed with the cycle ID; `forwardJumpPastBreakReturnsToIdle` renamed to `forwardJumpPastBreakCompletesTheCycle`.
  - I24: the flag tests were rewritten for completed: Start clears the end screen; editing durations now keeps it (`durationEditKeepsTheBreakEnd`); a relaunch now keeps it (`relaunchKeepsTheBreakEnd`); `theFlagIsNeverSaved` was removed, since completed is saved by design.
- Final run (`/tmp/FocusTimerTests-20261027-214628.xcresult`): `** TEST SUCCEEDED **`. `xcresulttool get test-results summary`: result Passed, `totalTestCount` 135, `passedTests` 135, `failedTests` 0, `skippedTests` 0, `expectedFailures` 0. That is the 121 I24 functions, minus the removed flag test, plus 15 new `TimerStoreCompletedStateTests` functions. No compiler warnings.

### Upgrade check, before (2026-10-27)

- The agent read the container preferences on the iPhone 18 Pro Max (iOS 27.0) with the app stopped: `config` = `{"durationBSeconds":60,"durationASeconds":60}`, `state` = `{"phase":"idle","paused":false}`, `schemaVersion` = `2`.

### User-reported

- 2026-10-27, Cmd+U in Xcode 27.1 (iPhone 18 Pro Max simulator, iOS 27.0): reported "done, results as expected" by the user; the summary line with the count was not included.
- 2026-10-27, upgrade and relaunch check, steps 2 to 6: the user reported all steps completed as expected (the app kept its state after the upgrade; "Cycle complete" showed after Break with the Break alert still in Notification Center; it survived a relaunch; leaving completed removed the alert). The user ran the steps without stopping for the agent's reads in steps 2 and 5.

### Upgrade check, after (2026-10-27)

- The agent read the container preferences afterwards, with the app running: `schemaVersion` = `3`, `config` = `{"durationASeconds":60,"durationBSeconds":60}` (unchanged), `state` = `{"paused":false,"phase":"idle"}`, consistent with leaving completed by Cancel at step 6. The completed state itself was not read from storage on the device; the unit tests cover its saved form.
