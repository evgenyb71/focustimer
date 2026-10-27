# I12 Settle expiry and clock-edge behavior

Status: verified (2026-10-27), after the Codex review finding was fixed: 109 test functions, all passed, 0 expected failures, agent-run on iPhone 17 Pro iOS 26.5, including two regressions for extreme saved deadlines that crash without the fix. Earlier evidence stands: user-reported Cmd+U on the iPhone 18 Pro Max (iOS 27.0), 107 tests in 8 suites passed, before the review fix; after it the user reported Cmd+U passed (summary line not given). Real clock changes on a device stay unverified. Implements roadmap phase I12, "Settle expiry and clock-edge behavior". Branch `feat/I12-expiry-clock-edges`.

Context: [roadmap](../roadmap.md), [mission](../mission.md), [tech stack](../tech-stack.md), previous phase [I11](I11-clean-up-alerts.md).

Roadmap exit check: pause at expiry completes; test duplicate callbacks, delayed activation, and forward and backward clock changes.

## Requirements

### Scope

The mission requires that "pause at or after expiry reconciles completion rather than adding time", and that wall-clock jump behavior is defined and tested while wall-clock deadlines stay the baseline. Today:

- `pauseOrResume()` on a running phase whose deadline has passed stores `max(1, …)` remaining seconds, so the phase pauses with 1 s left instead of completing. The I06 test `pauseAtExpiryCompletesInsteadOfAddingTime` records this as a known issue owned by I12.
- After a backward clock jump, a running deadline can be further away than the phase's full duration, and the timer shows more than its length.
- Saved data can hold a paused remaining time longer than the phase's duration; I07 left this unchecked.
- Forward jumps, duplicate callbacks, and delayed activation already behave correctly as far as the I06 to I11 tests show, but the roadmap asks for explicit tests.

### Decisions (user, 2026-10-27)

- **Scope: the pause fix, clock rules, and tests.**
- **Pause at or after expiry completes the phase.** Pausing first reconciles with the current time. If the deadline has passed, Focus waits for Break confirmation and Break returns to idle, exactly as if the timer had ended; nothing is paused. The `withKnownIssue` marker is removed.
- **Backward jump: cap at the full duration.** On reconcile, launch, or activation, a running deadline that is more than the phase's duration away is moved to now + duration, saved, and the completion alert rescheduled. No notice is shown; the timer never shows more than its length.
- **Over-long saved paused time: repair with the notice.** At launch, a paused remaining time longer than the phase's duration is clamped to the duration, saved, and the I07 correction notice is shown.
- **Validation:** agent-run unit tests with the injected clock, and user-reported Cmd+U. Real clock changes on a device or simulator stay unverified.

### Agent decisions within the user's choices (open to revision)

- **Phase duration** means the current configuration's normalized duration for that phase (`durationASeconds` for Focus, `durationBSeconds` for Break). Durations can only change while idle, so it matches the running phase. Limitation: if `config` was unreadable and replaced with defaults (I09) while a longer phase was running, the cap shortens that phase to the default length. Storing each phase's duration in the state would avoid this but needs a schema change; not in scope.
- **A saved running deadline that is too far away is capped silently,** even at launch. Launch cannot tell a backward jump while the app was closed from corrupt data, and the user chose no notice for the cap. Only an over-long paused time shows the notice.
- **Where the cap runs:** in `reconcileWithCurrentTime()`, which the ticker, launch, activation, and the notification action already call. The condition is strict (`deadline − now > duration`), so a just-started phase is never capped. When it applies, the pending completion is rescheduled for the new deadline with the same cycle ID.
- **Pause just before expiry** (deadline not yet passed) keeps today's behavior: remaining time rounds up to whole seconds, at least 1 s.
- **Forward jump:** a deadline that passes because the clock moved forward completes on the next reconcile, as today. Focus still waits for confirmation; a jump never skips Break confirmation or starts Break.
- **Duplicate callbacks and delayed activation:** add tests for repeated `activate()`, repeated `reconcileWithCurrentTime()` after a long delay, a pause after an unreconciled expiry, and a notification action after a forward jump. Each performs at most the one applicable transition and makes no extra notification calls.

### Non-goals

- Monotonic or uptime-based timing; deadlines stay wall-clock `Date`s.
- Storing phase durations in the saved state or any schema change.
- The completed state, Done, and Restart (I13 to I17).
- Real clock-change checks on a device or simulator.
- Changing alert content or the I11 cleanup rules.

### Affected components

- `ios/FocusTimer/FocusTimer/TimerStore.swift`: reconcile before pausing; the backward-jump cap in `reconcileWithCurrentTime()`; the paused-time clamp in the launch repair (`TimerState.repaired` would need the configuration, or a separate step after it).
- `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift`: remove the `withKnownIssue` marker; new tests for the rules above.
- `NotificationScheduler.swift`, `FocusTimerApp.swift`, `ContentView.swift`: no change expected.
- Docs after verification: [mission](../mission.md) (the pause and clock invariant is now implemented) and [tech stack](../tech-stack.md) gap note.

### Invariants to preserve

- A single authoritative timer state in `TimerStore`.
- Explicit Break confirmation: completing Focus by pause, reconcile, or a clock jump always waits for confirmation.
- Local persistence through the injected `KeyValueStore`: caps and clamps are saved.
- Deadline-based recovery: deadlines stay absolute wall-clock times; the cap only shortens a deadline that is impossible for the configured duration.

## Plan

1. **Pause at or after expiry**
   - [x] Reconcile at the start of `pauseOrResume()` when pausing; if the phase completed, stop there.
   - [x] Remove the `withKnownIssue` marker; add Break and after-expiry cases.
2. **Backward jump cap**
   - [x] In `reconcileWithCurrentTime()`, move a running deadline more than the phase's duration away to now + duration, save it, and reschedule the completion with the same cycle ID.
3. **Over-long saved paused time**
   - [x] At launch, clamp a paused remaining time longer than the phase's duration, save it, and show the correction notice.
4. **Tests** (Swift Testing, injected clock)
   - [x] Pause exactly at, and well after, the Focus and Break deadlines completes the phase with no pause and no extra notification calls.
   - [x] Backward jump while running (Focus and Break): the deadline is capped, saved, and rescheduled once; the display never exceeds the duration; a jump within the duration changes nothing.
   - [x] Launch with a saved deadline too far away: capped without notice. Launch with an over-long paused time: clamped with the notice.
   - [x] Forward jump past the Focus deadline waits for confirmation; past the Break deadline returns to idle; never starts Break.
   - [x] Duplicates and delays: repeated `activate()` and reconcile after a long delay perform one transition; a notification action after a forward jump starts Break once.
   - [x] Existing tests pass with zero expected failures.
5. **Docs**
   - [x] Record results here. Update the mission's invariant line and the tech-stack gap note.

## Validation

### Agent-run

Run after the Swift changes. Toolchain checks per `AGENTS.md` (`xcode-select -p`, `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list`). Then, from the repository root, on iPhone 17 Pro (iOS 26.5), not the user's simulator:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath /tmp/FocusTimerTests-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
```

Record `totalTestCount`, `passedTests`, `failedTests`, and expected failures from `xcrun xcresulttool get test-results summary --path <result bundle>`. Expected: the 95-function I11 baseline plus the new tests, all passing, with **0 expected failures** now that the I12 known issue is fixed.

### User-reported (Xcode)

- Product > Test (Cmd+U) passes with no known issues; report the summary line with the count.

### Remains unverified

- Real wall-clock changes (manual time change, time zone or daylight-saving change, network time correction) on a device or simulator.
- Pause at expiry by hand in the running app; covered by unit tests only.
- Other deferred OS rows from I02 (S1 to S3).

## Results

### Agent-run (2026-10-27)

- Toolchain: `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; Xcode 27.1; destination iPhone 17 Pro, iOS 26.5 (the user's iPhone 18 Pro Max was not used).
- First run (`/tmp/FocusTimerTests-20261027-192710.xcresult`): build error. `init` passed the `@Published` `configuration` to the clamp before every stored property was set; fixed with a local `normalizedConfiguration`.
- Second run (`/tmp/FocusTimerTests-20261027-192730.xcresult`): 107 tests, 5 failed, all from older fixtures that seeded timers longer than the configuration they loaded (10 min against the 1-min default, or a 10-min deadline against a 5-min Break). The new cap and clamp correctly shortened them. The fixtures were shortened to fit their configurations; their intent (migration, recovery, cycle repair) is unchanged:
  - `TimerStoreMigrationTests.state(_:)`: running deadline 600 s → 200 s (inside the 5-min Break).
  - `TimerStoreRecoveryTests`: running Focus deadline 600 s → 30 s; paused 900 s → 30 s (default 1-min config after the corrupt config).
  - `TimerStoreCycleTests`: version 1 and 2 running deadlines 600 s → 30 s; paused Focus 300 s → 45 s (no saved config, so 1-min defaults).
- Final run (`/tmp/FocusTimerTests-20261027-193827.xcresult`): `** TEST SUCCEEDED **`. `xcresulttool get test-results summary`: result Passed, `totalTestCount` 107, `passedTests` 107, `failedTests` 0, `skippedTests` 0, `expectedFailures` 0. That is the 95 I11 functions plus 12 new `TimerStoreClockEdgeTests` functions; the former known issue `pauseAtExpiryCompletesInsteadOfAddingTime` now passes without its `withKnownIssue` marker.
- Build results: no compiler warnings.

### Implementation notes

- `Configuration.duration(of:)` returns the full length of a timed phase.
- `TimerState.clampingPausedTime(to:)` runs after `repaired` at launch, so the existing notice logic shows the correction notice when it changes the state.
- `pauseOrResume()` calls `reconcileWithCurrentTime()` when pausing, then pauses only if the phase is still running.
- The cap lives in `reconcileWithCurrentTime()`, so the ticker, launch, activation, and the notification action all apply it. It reschedules the completion with the same cycle ID.
- `launchWithCorruptConfigurationCapsALongerRunningPhaseToTheDefault` documents the known limitation rather than hiding it.

### User-reported

- 2026-10-27, Cmd+U in Xcode 27.1 (iPhone 18 Pro Max simulator, iOS 27.0): "Test run with 107 tests in 8 suites passed after 0.024 seconds", as reported by the user. No known issues remain.

## Review finding and handoff (Codex, 2026-10-27)

### P2: extreme saved deadlines can crash before launch reconciliation

Approval is withheld until this finding is fixed and verified. The earlier passing results do not cover this case; the original pause-at-expiry defect remains fixed.

- **Location:** `ios/FocusTimer/FocusTimer/TimerStore.swift`, initializer (lines 160–161 at review time), and `updateDisplayedTime()` (line 349).
- **Evidence:** source review plus a focused Foundation decoding probe, not a simulator reproduction. JSON containing `{"phase":"runningA","paused":false,"endTimestamp":1e20}` decodes successfully into a `Date`; the probe confirmed that the remaining interval exceeds the `Int` conversion range. A full saved-state fixture should also include a valid cycle ID so it isolates this deadline issue from I10 repair.
- **Cause:** the initializer calls `updateDisplayedTime()` before `reconcileWithCurrentTime()`. Display calculation evaluates `Int(ceil(deadline.timeIntervalSince(clock.now)))` before clamping the integer result. For an extreme future or past deadline, that conversion traps before the new reconciliation logic can cap the deadline or complete the expired phase.
- **Impact:** a successfully decoded but extreme saved timestamp prevents the app from launching, instead of recovering under I12's saved-deadline rules.
- **Required fix:** reconcile the loaded state before the initial countdown conversion. Avoid any display calculation on the unbounded saved deadline before reconciliation has capped or completed it. Preserve normal display initialization for idle, waiting, paused, and valid running states.

### Remaining work and acceptance checks

- [x] Correct the initialization order as described above.
- [x] Add launch regressions with valid configuration, current schema version, valid cycle ID, and extreme finite timestamps (for example `1e20` and `-1e20`) for Focus and Break.
- [x] Verify that extreme future deadlines launch safely, cap to now + the configured phase duration, persist the capped state, reschedule with the same cycle ID, and display the bounded countdown.
- [x] Verify that extreme past deadlines launch safely and perform only the applicable transition: Focus waits for Break confirmation; Break returns to idle. Confirm persistence and no automatic Break start.
- [x] Run the FocusTimer unit suite per the toolchain and destination checks in `AGENTS.md`; confirm and record the executed count from the result bundle, with zero failures and zero expected failures.
- [x] Record the fix and actual validation results here; restore verified status only after the finding is resolved.

Review checks: `git diff --check main..HEAD` passed. Codex independently read `/tmp/FocusTimerTests-20261027-193827.xcresult`: 107 test functions passed, 0 failed, 0 expected failures. Those results predate this finding's fix. No unit suite or simulator flow was rerun during review; the Foundation probe only confirmed decoding and the out-of-range interval.

At handoff, the working tree was clean on `feat/I12-expiry-clock-edges` at `71cd569` before this documentation edit. The phase doc is on that branch, so the review note is left there, uncommitted. This request changes only the phase document; implementation, commits, push, merge, and deletion are not part of it.

### Agent feedback on the finding (Claude Code, 2026-10-27)

- **Confirmed.** `init` called `updateDisplayedTime()` before `reconcileWithCurrentTime()`, and the display converted `ceil(deadline − now)` to `Int`, which traps outside about ±9.2e18 seconds. A saved deadline of `1e20` or `-1e20` decodes as a valid `Date`, so launch crashed before the cap or completion could run. The unfixed run below reproduces this.
- **Not introduced by I12.** The order dates from the app's first build. Before I12 the same deadline also trapped on every tick, with no recovery; I12's cap is what makes recovery possible.
- **Trigger.** Only corrupt or tampered saved data reaches this range; even a clock set to the year 3000 gives about 3e10 seconds. P2 is still right, because I09 and I12 promise recovery from bad saved data.
- **Other inputs checked.** Paused, waiting, and idle states have stray deadlines removed by the I07 repair, and over-long paused times are clamped. Infinite and NaN dates cannot be decoded (Foundation's JSON decoder rejects non-conforming floats by default). The alert interval is computed after the cap.

### Resolution (Claude Code, 2026-10-27)

- **Fix (`TimerStore.swift`, `init`):** `reconcileWithCurrentTime()` now runs first and the earlier `updateDisplayedTime()` call is removed. Reconcile works in `Double`, caps or completes the deadline, and updates the display itself on every path, so idle, waiting, paused, and valid running states still get their initial display.
- **Hardening (agent suggestion, approved by the user):** both `Int(ceil(...))` conversions, in `updateDisplayedTime()` and when pausing, go through `wholeSecondsUntil(_:)`, which bounds the value to the `Int32` range before converting. The reorder alone fixes the finding; the helper keeps a later reorder or a path that skips the cap from reintroducing the trap.
- **Regressions (`TimerStoreClockEdgeTests`):** valid 25/5 configuration, current schema version, valid cycle ID.
  - `launchWithAnExtremeFutureDeadlineCapsItInsteadOfCrashing` (Focus and Break, `1e20`): launches; the deadline is capped to now + the phase duration, saved, and rescheduled once with the same cycle ID, as the only pending-request call; the display shows the full duration; no notice; pausing 10 s later stores duration − 10.
  - `launchWithAnExtremePastDeadlineCompletesInsteadOfCrashing` (Focus and Break, `-1e20`): launches; Focus waits for Break confirmation with its cycle ID, Break returns to idle; both saved; no Break started or scheduled.
- **Validation:**
  - With the fix (`/tmp/FocusTimerTests-20261027-200928.xcresult`): `** TEST SUCCEEDED **`; result Passed, `totalTestCount` 109, `passedTests` 109, `failedTests` 0, `skippedTests` 0, `expectedFailures` 0 (107 earlier functions plus the 2 regressions). No compiler warnings.
  - Without the fix (`/tmp/FocusTimerTests-20261027-201023-unfixed.xcresult`): the old `init` order and an unbounded `Int(seconds)` were restored temporarily and only the two regressions run: 2 tests, 2 failed, both "Test crashed with signal trap". The fixed `TimerStore.swift` was then restored and checked byte-identical (`cmp`) to the source of the passing run.
  - Toolchain: Xcode 27.1; destination iPhone 17 Pro, iOS 26.5.
- **User-reported (2026-10-27):** after this fix the user reported "Cmd+U passed" (Xcode 27.1, iPhone 18 Pro Max simulator, iOS 27.0); the summary line with the count was not included.
- **Remaining limitations:** covered by unit tests only, not reproduced in the running app.
