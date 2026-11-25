# I45-I46 Fix the ticker lifetime and share the reset logic

Status: verified

## Goal

Releasing a timer store stops its one-second ticker, and unit tests run without automatic ticks. The duplicate display refresh on each tick is gone, and Cancel and Done share one reset path. Nothing the user sees changes.

Roadmap exit check: a regression proves that releasing a short-lived store leaves no valid scheduled ticker, and deterministic tests still control time explicitly; tests cover countdown updates, Cancel and Done, and notification cleanup order; a user-reported simulator check covers the countdown, pause and resume, and return from the background.

## Decisions

User, 2026-11-25:

- **One phase:** I45 and I46 together, because they are small and touch the same code.
- **Ticking option:** on by default, so the app's store needs no change, and every store the unit tests create turns it off. The user chose this over off by default and over an injected ticker boundary.
- **Checks:** Cmd+U and the short flow below.

Agent decisions, open to revision:

- **Teardown:** the store invalidates its ticker when it is released. It uses an `isolated deinit`, which runs on the main actor, so no unsafe workaround is needed.
- **Regression:** a test creates a store with ticking on, releases it, and checks that the ticker it scheduled is no longer valid. It must fail without the fix. The tick tests also keep ticking on and fire the ticker by hand; every other test turns it off.
- **Opting out:** tests pass the option at each place they create a store. A new test that forgets it still passes, but ticks; a shared helper is worth revisiting if that happens.
- **Shared reset:** Done keeps its guard (completed only) and saves its durations before the reset. Cancel stays unguarded and keeps the configuration. The order stays: state, notice, pending alerts, delivered alerts, save, display.
- **Saved data:** no change, and no new `schemaVersion`.

## Non-goals

- The separations planned as I47 and I48.
- Stopping the ticker in idle or in the background, or changing its interval.
- Any visible, notification, or timing change.

## Plan

Tick an item only when it is done.

- [x] Add the ticking option, on by default, and turn it off at every store the unit tests create.
- [x] Write the release regression and confirm that it fails before the fix.
- [x] Invalidate the ticker when its store is released; confirm that the regression passes.
- [x] Remove the duplicate display refresh from the tick, with a test that a tick updates the countdown and completes an expired phase.
- [x] Share the Cancel and Done reset, with tests for both actions and their notification cleanup order.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] User: run Cmd+U and the short flow; record in Results as user-reported.
- [x] Update the [tech stack](../tech-stack.md) on the ticker and its option, and the README's next planned work. The [mission](../mission.md) changes only if behavior does.
- [x] Set `Status: verified` and move the roadmap row to Completed.
- [x] Open the PR; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run: `scripts/test.sh`.

User-reported, in Xcode, with `scripts/debug-minute.sh 10` and two-minute durations (20 seconds each):

1. Cmd+U passes.
2. Start Focus: the time counts down once per second. Pause: it stops. Resume: it continues from the same time.
3. Go to the Home Screen and return before the deadline: the time is correct.
4. Go to the Home Screen and return after the deadline: "Focus complete" is shown and Break has not started.
5. Start Break and let it end with the app open: "Cycle complete" is shown. Done returns to idle and keeps the durations.
6. Start Focus and press ×: idle, with the durations kept, and no alert arrives at the old deadline.

Stays unverified: a physical device; long suspension by iOS.

## Results

Agent-run, 2026-11-25, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
FocusTimer on iPhone 17 Pro, iOS 26.5: total 265, passed 265, failed 0, skipped 0, expected failures 0
PASSED
```

That is the 258 earlier tests and 7 new ones in `TimerStoreTickerTests`. The 22 existing places that create a store turn ticking off.

Without the fix, only `releasingTheStoreInvalidatesItsTicker` failed (264 of 265 passed), with `stillValid → true`. A first version of that assertion also failed without the fix but printed a contradictory value, so the check was made explicit and run again without and with the fix.

Implementation note: the tick did nothing but reconcile once its extra refresh was gone, so the ticker now calls `reconcileWithCurrentTime()` directly.

User-reported, 2026-11-25, on the user's simulator with `scripts/debug-minute.sh 10`: all six checks passed, including Cmd+U. The device, OS version, and test count were not stated.

The mission is unchanged, because behavior is.

Remaining limitations: a physical device; long suspension by iOS.

### Review

Codex review of the PR, as reported by the user on 2026-11-25: no correctness findings; recommended approving. Codex ran the unit tests itself: 265 passed, no failures or skips. No code changed, so no checks were rerun.
