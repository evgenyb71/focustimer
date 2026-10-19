# I02 Exercise pause/resume, cancel, relaunch, suspension, and notifications

Status: verified (2026-10-19) for the rows run, with deferrals: P1-P4, C1-C4, R1 passed (user-reported); R2, R4 passed (agent-run, iOS 26.5 simulator); R3, R5, S1-S3, N1-N8 deferred by the user to later stages and unverified. No defects found in the rows run. Implements roadmap phase I02 in the [iOS roadmap](../roadmap.md).

Context: [mission](../mission.md), [tech stack](../tech-stack.md), previous phase [I01](I01-record-baseline-flow.md).

## Requirements

### Scope

- Manually exercise the behaviors I01 left out: pause/resume, cancel, relaunch, suspension (background/foreground), and notification permission and actions.
- Record a state/action matrix (below) with the expected result drawn from the code and [mission](../mission.md), then the observed result, and classify each deviation as a **code defect** or **OS behavior**.
- Fix a defect only if it blocks the flow (the smallest change that unblocks it); log all others and assign them to the later roadmap phase that owns them.

### Non-goals

- Injection of clock, persistence, or notification boundaries; tests; refactors (I03 to I06).
- Fixing non-blocking defects: validation (I07), migration/recovery (I08, I09), cycle identity and stale actions (I10), delivered-notification cleanup (I11), expiry/clock edges (I12), launch-state policy (I22), permission guidance (I18).
- Physical-device checks, accessibility, visual changes, `chrome/`.

### Decisions

- Environment: simulator only (same as I01: iPhone 18 Pro Max, iOS 27, Xcode 27.0, unless the user reports otherwise). Rows that need a real lock screen, true process suspension, or delivery under system restrictions are recorded as unverified, not inferred.
- The agent drafts the matrix; the user runs each row in Xcode and reports observed results. Results are recorded as user-reported. The agent does not claim GUI flow checks as its own.
- Defects that block the flow may be fixed in this phase; each is listed with its commit and re-run evidence. If nothing blocks, no Swift changes are made and the phase is documentation only.

### Context from the current code

- `TimerStore.pauseOrResume()` stores `remainingSeconds` (min 1) and cancels the pending notification on pause; resume sets a new deadline and reschedules.
- `TimerStore.cancel()` resets state, removes pending requests, keeps configuration; it does not remove delivered notifications (I11).
- `reconcileWithCurrentTime()` runs at init, every tick, and on `scenePhase == .active`; an expired unpaused deadline performs only the applicable transition.
- The Focus notification has category `FOCUS_COMPLETE` with one action `START_BREAK` ("OK", foreground). The Break notification has no actions. A plain tap on a notification takes no action other than opening the app.
- `willPresent` returns banner, list, and sound, so notifications appear while the app is in the foreground.
- Authorization is requested at launch (`.alert`, `.sound`); the result is ignored.

### Affected components

Read-only unless a blocking defect is fixed: `ios/FocusTimer/FocusTimer/TimerStore.swift`, `NotificationScheduler.swift`, `FocusTimerApp.swift`, `ContentView.swift`.

### Invariants to preserve

Single authoritative timer state, explicit Break confirmation, local persistence, deadline-based recovery. Any blocking fix must not weaken these.

## Plan

1. Prepare the matrix
   - [x] Confirm the expected results in the matrix below against the code and mission.
   - [x] Agree row order and the environment with the user.
2. User-run exercise
   - [x] User runs each row in Xcode on the simulator and reports observed results (use short durations such as 1 minute; a longer Focus makes suspension rows easier).
   - [x] Record observed results as user-reported in Results.
3. Classify and close out
   - [x] Classify each deviation as code defect or OS behavior, with the owning later phase.
   - [x] Fix only flow-blocking defects; re-run the affected rows.
   - [x] Run the build command if Swift or project files changed.
   - [x] Set status to verified only with the evidence above; update the [roadmap](../roadmap.md) and run `/update-changelog` before merging.

## Validation

### Agent-run

Only if Swift or project files change (none expected):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FocusTimerDerivedData CODE_SIGNING_ALLOWED=NO build
```

A build alone does not verify runtime behavior. There is no test target.

### User-reported state/action matrix (Xcode, simulator)

Fill the Observed and Class columns in Results. "Pending" means a notification request still scheduled; check by waiting past the deadline in a background state.

| # | Start state | Action | Expected |
| --- | --- | --- | --- |
| P1 | Focus running | Pause | Countdown freezes, shows "Focus paused", pending Focus alert removed (no alert at the old deadline) |
| P2 | Focus paused | Resume | Counts down from the frozen value, new alert scheduled for the new deadline |
| P3 | Break running | Pause, then Resume | Same as P1/P2 for Break |
| P4 | Focus paused | Wait longer than the remaining time | No transition and no alert; time does not advance |
| C1 | Focus running | Cancel | Idle, durations retained, no alert at the old deadline |
| C2 | Focus paused | Cancel | Idle, durations retained |
| C3 | Waiting for Break confirmation | Cancel (the xmark control is always shown) | Idle, durations retained |
| C4 | Break running | Cancel | Idle, durations retained, no Break alert |
| R1 | Focus running | Force-quit and relaunch before the deadline | Resumes with correct remaining time from the saved deadline |
| R2 | Focus running | Force-quit, relaunch after the deadline | Waiting for Break confirmation; Break not started |
| R3 | Focus paused | Force-quit and relaunch | Still paused with the same remaining time |
| R4 | Waiting for Break confirmation | Force-quit and relaunch | Still waiting (see launch-state policy, I22) |
| R5 | Break running | Force-quit, relaunch after the deadline | Idle, durations retained |
| S1 | Focus running | Background the app (Home), return before the deadline | Correct remaining time on return |
| S2 | Focus running | Background, return after the deadline | Waiting for Break confirmation on return; Break not started |
| S3 | Focus paused | Background and return | Still paused, time unchanged |
| N1 | Fresh install | First launch | Permission prompt appears; app usable after Allow or Don't Allow |
| N2 | Permission allowed | Focus expires in foreground | Banner appears; app shows waiting for confirmation |
| N3 | Permission allowed | Focus expires in background | Banner with OK action appears |
| N4 | Focus notification shown | Tap OK action | App opens and Break starts once |
| N5 | Focus notification shown | Tap the notification body (not OK) | App opens in waiting for confirmation; Break does not start |
| N6 | Focus notification shown, app already waiting | Tap OK twice or after Start Break | No extra phase or restart (harmless duplicate) |
| N7 | Break expires in background | Observe | Break alert without actions; app idle on return |
| N8 | Permission denied (Settings > Notifications) | Run Focus to expiry, then Break | No alerts; in-app transitions still work and are not blocked |

Rows that need a physical device (lock screen, real suspension, Focus modes, delivery under low power) are recorded as unverified. Classification: **code defect** (app logic deviates from the mission or this table) or **OS behavior** (simulator or system policy, for example notification timing or presentation).

### Unverified after this phase

Physical device; iOS 26.x runtime; accessibility; clock or time-zone changes (I12); stale or duplicate action provenance (I10); delivered-notification cleanup (I11).

## Results

Closed out 2026-10-19 with the rows below. The remaining rows are deferred by the user's decision, not verified.

### Agent-run (2026-10-19, simulator driven by the agent)

- Environment: iPhone 17 Pro simulator, iOS 26.5, Xcode 27.0; separate from the user's iPhone 18 Pro Max (iOS 27) session. Agent build with derived data in `/tmp/FocusTimerDerivedData` (`** BUILD SUCCEEDED **`, destination `platform=iOS Simulator,id=<iPhone 17 Pro>`). App installed and launched with the simulator tool; taps and screenshots by the agent; force-quit and relaunch with `xcrun simctl terminate`/`launch`. `xcode-select` was switched to full Xcode by the user.
- Method note: UI state was read from screenshots only. Pending or delivered notifications were not inspected.

| # | Observed (agent-run) | Result |
| --- | --- | --- |
| P1 | Pause at 00:52 showed "Focus paused" at 00:45; unchanged after a further ~6 s wait | UI pass; removal of the pending alert not checked |
| P2 | Resume continued from the frozen value (00:45 to 00:42 running) | UI pass; new alert not checked |
| C1 | Cancel during Focus returned to Ready with 1 min / 1 min kept | UI pass; absence of an alert at the old deadline not checked |
| R1 | Force-quit at 00:57 (15:28:13), relaunch at 15:28:24 showed 00:46, running | Pass |
| R2 | Force-quit during Focus, relaunch after the deadline showed "Focus timer complete", 00:00, Start Break; Break not started | Pass |
| R4 | Force-quit and relaunch in the waiting state showed the same waiting screen | Pass (launch-state policy is I22) |

Not yet run by the agent: P3, P4, C2 to C4, R3, R5, S1 to S3, and all N rows. The first-launch permission prompt (N1) was not seen in the agent's screenshots; this is not recorded as a result either way.

### User-reported matrix (2026-10-19)

- Environment: Xcode simulator, as reported by the user (device and OS version not itemized).
- P1, P2, P3, P4, C1, C2, C3, C4, R1: **pass**. Per-row observations were not itemized, and whether alerts were suppressed or rescheduled was not separately reported.

### Deferred rows

The user postponed these to later stages of the project (2026-10-19). They are unverified, with no result recorded:

| Rows | What is deferred | Natural home |
| --- | --- | --- |
| R3, R5 | Relaunch while paused; relaunch after Break expiry | I12 / I22 |
| S1, S2, S3 | Backgrounding and returning (before and after the deadline, paused) | I12 |
| N1-N8 | Permission prompt, alerts in foreground and background, OK action, body tap, duplicate actions, Break alert, denied permission | I10, I11, I18, I21 |

The exact later phase for each is a suggestion; the [roadmap](../roadmap.md) is not changed by this note.

### Defects and classification

No code defects or OS-behavior deviations were found in the rows run. Rows that were not run could not expose any.

### Remaining limitations

- Notification behavior (N1-N8) is untested, including whether pause and cancel actually remove pending alerts; only the UI state was observed.
- Suspension (S1-S3), paused and Break-expiry relaunch (R3, R5), physical device, and iOS 26.x for the user-reported rows remain unverified. The agent-run rows used iOS 26.5; the user's run used the simulator they reported.
