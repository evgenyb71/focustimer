# I06 Baseline transition and deadline tests

Status: verified (2026-10-20): 36 test functions (44 cases including parameterized) pass except one known issue owned by I12, agent-run with counts from the result bundle (iPhone 17 Pro, iOS 26.5) and user-reported Cmd+U; no app code changed. Commits `06b2eef`, `65c81f8`, `77f91b9`.

Context: [mission](../mission.md), [tech stack](../tech-stack.md), previous phase [I05](I05-notification-boundary-tests.md).

Roadmap exit check: tests cover Focus/Break, explicit confirmation, pause/resume, cancel, and delayed reconciliation.

## Requirements

### Scope

Deterministic Swift Testing tests for today's `TimerStore` behavior, using the I05 test doubles (`FakeClock`, `InMemoryStore`, `RecordingNotificationScheduler`):

- **Focus and Break:** start Focus from idle; Focus expiry enters waiting for confirmation; Break runs only after confirmation; Break expiry returns to idle with configuration retained; start actions are ignored in the wrong state.
- **Explicit confirmation:** Break never starts by itself, however long after the Focus deadline reconciliation runs.
- **Pause and resume:** frozen remaining time, no transition while paused, resume from the remaining time, for both Focus and Break; pause and resume are ignored outside running phases.
- **Cancel:** from running, paused, and waiting states, returns to idle with configuration retained.
- **Delayed reconciliation:** a late reconcile performs only the applicable transition (Focus to waiting; Break to idle) and does not replay missed ticks.
- **Relaunch from store** (added by user decision): a second `TimerStore` built from the same in-memory store, with the clock advanced, restores running, paused, and waiting states and reconciles a passed deadline at launch. This covers the logic of the deferred I02 rows R3 and R5 deterministically, not OS lifecycle.
- **Notification OK path** (added by user decision): `startBreakFromNotification` after Focus expiry starts Break once; repeated, early, or idle calls change nothing. Logic only, not OS delivery.
- **Display countdown** (added by user decision): `displayedSeconds` while running (rounded up), paused (remaining), waiting (0), and idle (nil).
- **Small fixes:** if a test exposes a defect in these transitions that contradicts the [mission](../mission.md), it may be fixed here with a minimal change, its own commit, and a covering test.
- **Housekeeping:** replace "pending push" in the roadmap's I05 completed row with `131616d` on `main`, and tick the leftover "fill in the pushed commit" items in the I03-I04 and I05 specs.

### Non-goals

- Topics owned by later phases are logged, not fixed, even if small: duration bounds and invalid stored state (I07), schema and migration (I08), corrupt-record recovery (I09), cycle identity and stale or duplicate notification provenance (I10, I11), expiry and clock edges such as pause at or after expiry and clock jumps (I12), launch-state policy (I22). Where a test documents such a known deviation, it uses Swift Testing's `withKnownIssue` with a note naming the owning phase.
- OS notification delivery, the OK action from a real notification, lifecycle, and physical-device checks (deferred I02 rows).
- UI tests and visual changes; `chrome/`.

### Decisions

- Tests extend the existing `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift` (user decision), as additional `@MainActor` suites or tests beside `TimerStoreNotificationTests`, reusing `TestDoubles.swift`. Use `@Test(arguments:)` where Focus and Break behave symmetrically.
- Each test builds its own clock, store, and scheduler, so parallel execution shares no state. Tests drive time only through `FakeClock` and call `reconcileWithCurrentTime()` explicitly; they do not wait for the one-second ticker.
- Defect handling: fix only defects in the I06 transitions themselves (a few lines, own commit, own test); defer roadmap-owned topics as listed in Non-goals.
- Validation: agent `xcodebuild test` with the count confirmed from the result bundle; user Cmd+U once. A simulator flow check runs only if a production fix lands.

### Context from the current code

- `TimerStore` phases: `idle → runningA → waitingForAConfirm → runningB → idle`; `paused` is a flag on a running phase with `remainingSeconds` and no `endTimestamp`.
- `pauseOrResume()` on pause stores `max(1, ceil(deadline - now))`, so pausing at or after the deadline stores 1 second instead of completing (mission: "Pause at or after expiry reconciles completion rather than adding time"); owned by I12.
- `init` decodes `config` and `state` from the store, then reconciles; `startBreakFromNotification()` reconciles and then calls `startBreak()`, which is guarded to the waiting state.
- `startFocus()` rejects durations below one second only; the minute ranges are not enforced in the store (I07).

### Affected components

- `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift` (new tests); `TestDoubles.swift` only if a helper is needed.
- `ios/FocusTimer/FocusTimer/TimerStore.swift` only if a small in-scope fix is needed.
- `specs/ios/roadmap.md` (I05 hash, I06 close-out), I03-I04 and I05 specs (checkbox housekeeping), [tech stack](../tech-stack.md) only if test coverage notes change.

### Invariants to preserve

Single authoritative timer state, explicit Break confirmation, local persistence (same keys and encoding), deadline-based recovery. Tests assert these; any fix must not weaken them.

## Plan

1. Housekeeping (small commit)
   - [x] Roadmap I05 row: `131616d` on `main`; tick the leftover items in the I03-I04 and I05 specs.
2. Transition tests (commit)
   - [x] Focus/Break and explicit confirmation, including wrong-state start calls.
   - [x] Pause and resume for Focus and Break; ignored outside running phases.
   - [x] Cancel from running, paused, and waiting.
   - [x] Delayed reconciliation for Focus and Break.
3. Relaunch, notification path, and display tests (commit)
   - [x] Relaunch from the same store: running before and after the deadline, paused, waiting, Break after the deadline.
   - [x] `startBreakFromNotification`: after expiry, repeated, early, idle.
   - [x] `displayedSeconds` in each state.
4. Defects, verification, and close-out
   - [x] For any failing expectation: classify as in-scope defect (fix with own commit and test) or later-phase topic (`withKnownIssue` plus a note here).
   - [x] Run `xcodebuild test`; confirm counts from the result bundle; record. Simulator flow check only if production code changed.
   - [x] Record the user's Cmd+U result.
   - [x] Set status to verified only with evidence; move I06 to the roadmap's completed table.
   - [ ] The user runs `/update-changelog` before merging; fill in the pushed commit in the roadmap after the push.

## Validation

### Agent-run

Toolchain checks as in `AGENTS.md`, then on an installed simulator the user is not using:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath /tmp/FocusTimerTests-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
xcrun xcresulttool get test-results summary --path <result bundle>
```

Expected: `result: Passed`; `totalTestCount` equals the number of test cases (including parameterized cases) with `failedTests: 0`; known issues, if any, listed with their owning phase. No new compiler warnings.

If production code changes: the build command from `AGENTS.md` and the short agent simulator flow check from [I05](I05-notification-boundary-tests.md) (Start, Pause, Resume, Cancel, Focus and Break to expiry) on the iPhone 17 Pro.

### User-reported

Run the tests in Xcode with Cmd+U on any iOS 26+ simulator; report pass or fail and the simulator used.

### Unverified after this phase

- OS notification delivery, real OK action, denied permission, suspension, and physical device (deferred I02 rows).
- Behaviors owned by later phases and documented as known issues.

## Results

### Plan group 1: housekeeping (2026-10-20)

- [Roadmap](../roadmap.md) I05 completed row now shows `131616d` on `main`; the leftover "fill in the pushed commit" items in the [I03-I04](I03-I04-inject-clock-and-store.md) and [I05](I05-notification-boundary-tests.md) specs are ticked.

### Plan group 2: transition tests (agent-run, 2026-10-20)

- Added to `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift`: test-only enums `TimedPhase` (Focus, Break) and `CancelStart` (five starting states), and the `@MainActor` suite `TimerStoreTransitionTests` with Focus 120 s and Break 30 s so the two durations are distinguishable. Helpers build idle, running, and waiting timers from the shared doubles and decode the saved `state` and `config` from the in-memory store. No app code changed.
- Tests: `startFocusRunsFocusAndPersistsConfiguration`, `primaryActionStartsFocusFromIdleAndConfirmsBreakFromWaiting`, `startFocusIsIgnoredOutsideIdle`, `startBreakIsIgnoredOutsideWaiting`, `focusExpiryWaitsForConfirmation` (one second before the deadline still running; at the deadline waiting, saved, no new schedule), `breakNeverStartsByItself` (three reconciles 10,000 s apart), `breakExpiryReturnsToIdleKeepingConfiguration`, `pauseFreezesRemainingTime` and `resumeContinuesFromRemainingTime` (each for Focus and Break), `pauseIsIgnoredOutsideRunningPhases`, `cancelReturnsToIdleKeepingConfiguration` (running Focus, paused Focus, waiting, running Break, paused Break), `delayedFocusReconciliationOnlyEntersWaiting`, `delayedBreakReconciliationOnlyReturnsToIdle`, and `pauseAtExpiryCompletesInsteadOfAddingTime`.
- Known issue (not fixed, owned by [I12](../roadmap.md)): pausing exactly at the Focus deadline before reconciliation stores 1 s remaining instead of completing, contrary to the [mission](../mission.md) ("Pause at or after expiry reconciles completion rather than adding time"). The test wraps its expectation in `withKnownIssue`; when I12 fixes the behavior, the test will fail until the marker is removed.
- Command: the Validation test command, result bundle `/tmp/FocusTimerTests-20261020-150612.xcresult`, iPhone 17 Pro, iOS 26.5, Xcode 27.0. `** TEST SUCCEEDED **`.
- Result bundle summary: `result: Passed`; 20 test functions (`totalTestCount: 20`: 19 passed, 1 expected failure, 0 failed, 0 skipped); counting parameterized cases, 25 passed and 1 expected failure. The per-test tree lists all six I05 tests and every I06 test and argument as Passed, except the known issue as Expected Failure. No compiler warnings; only the unrelated `appintentsmetadataprocessor` tool warning.
- No defects requiring a fix in this phase were found.

### Plan group 3: relaunch, notification OK path, and display tests (agent-run, 2026-10-20)

- Added as an extension of `TimerStoreTransitionTests` in `FocusTimerTests.swift`, with a `relaunch()` helper that builds a second `TimerStore` from the same clock, store, and scheduler. No app code changed.
- Relaunch: `relaunchBeforeDeadlineRestoresRunningPhase` (Focus and Break: same state and saved durations, no new notification calls), `relaunchAfterFocusDeadlineWaitsForConfirmation`, `relaunchAfterBreakDeadlineReturnsToIdle` (logic of deferred I02 R5), `relaunchWhilePausedKeepsRemainingTime` (Focus and Break; logic of deferred I02 R3), `relaunchWhileWaitingStaysWaiting`.
- Notification OK path: `notificationOKAfterFocusExpiryStartsBreakOnce` (reconciles, starts Break at the call time, schedules one Break completion; a second call changes nothing), `notificationOKBeforeFocusExpiryDoesNothing`, `notificationOKWhilePausedDoesNothing`, `notificationOKWhenIdleDoesNothing`.
- Display: `displayWhileRunningRoundsUp` (120 at start and after 0.4 s, 119 after 1 s), `displayWhilePausedShowsRemainingTime` (paused at 10.5 s shows 110 and stays there), `displayIsZeroWhileWaiting`, `displayIsNilWhenIdle` (fresh and after cancel).
- First run (`/tmp/FocusTimerTests-20261020-152807.xcresult`): 2 failures, both test-design mistakes, not app defects. Each test shares one in-memory store, so a second `TimerStore` created later in the same test loads the first one's saved state (a relaunch): the "idle" timer in the display test showed 0 (waiting) and in the notification test was paused Focus. The group 2 test `startFocusIsIgnoredOutsideIdle` had the same latent ordering and passed by coincidence. Fix: every test that built two unrelated timers was split into single-timer tests (`startFocusIsIgnoredWhileRunning`/`WhileWaiting`, `startBreakIsIgnoredWhenIdle`/`WhileFocusRuns`, `pauseIsIgnoredWhenIdle`/`WhileWaiting`, and the two notification and display splits above); a script check confirmed no test body creates more than one timer except the cancel test's mutually exclusive switch branches. Relaunch tests share the store on purpose.
- Final run: result bundle `/tmp/FocusTimerTests-20261020-152947.xcresult`, iPhone 17 Pro, iOS 26.5, Xcode 27.0; `** TEST SUCCEEDED **`. Summary: `result: Passed`; 36 test functions (`totalTestCount: 36`: 35 passed, 1 expected failure, 0 failed, 0 skipped); counting parameterized cases, 43 passed and 1 expected failure. The only non-passing test is the I12 known issue `pauseAtExpiryCompletesInsteadOfAddingTime` (Expected Failure). No compiler warnings; only the unrelated `appintentsmetadataprocessor` tool warning.
- No app defects found in I06 scope, so no production code changed and the simulator flow check is not needed.

### User-reported tests (2026-10-20)

- The user ran the tests in Xcode with Cmd+U: all 36 passed except one failure shown as expected (the I12 known issue `pauseAtExpiryCompletesInsteadOfAddingTime`). The simulator used was not itemized.

### Close-out (2026-10-20)

- Exit check met: tests cover Focus/Break, explicit confirmation, pause and resume, cancel, and delayed reconciliation, plus relaunch from the store, the notification OK path, and the displayed countdown.
- [Roadmap](../roadmap.md): I06 moved to the completed table; pushed commit pending.
- Known issue carried forward: pause at or after expiry stores 1 s remaining instead of completing (owned by I12; marked with `withKnownIssue`, which fails once fixed so the marker gets removed).
- Remaining limitations: no app code changed in this phase; OS notification delivery, the real OK action, denied permission, suspension, and physical device remain the deferred I02 rows; duration bounds and invalid stored state are untested until I07.
