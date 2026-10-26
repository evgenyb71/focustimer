# I11 Clean up obsolete pending and delivered notifications

Status: verified (2026-10-26): 94 test functions (93 passed, 1 expected failure for I12), agent-run on iPhone 17 Pro iOS 26.5; user-reported Cmd+U and the full Notification Center check on the iPhone 18 Pro Max (iOS 27.0) after fixing a pre-existing crash when tapping a notification's OK (see the defect section). The check replaces the I10 stale-alert ToDo. Implements roadmap phase I11, "Clean up obsolete pending and delivered notifications". Branch `feat/I11-clean-up-alerts`.

Context: [roadmap](../roadmap.md), [mission](../mission.md), [tech stack](../tech-stack.md), previous phase [I10](I10-cycle-identity.md).

Roadmap exit check: Cancel, phase change, and a new cycle invalidate old alerts; the current valid alert remains actionable.

## Requirements

### Scope

Today `TimerStore` removes pending completion requests on pause, Cancel, and repair, but never removes delivered alerts. A Focus alert therefore stays in Notification Center after Break starts, after Cancel, and into later cycles. Since I10 its OK is ignored, but the alert is still there. This phase removes delivered alerts once they no longer match the timer, and keeps the one alert that still matters: a delivered Focus alert while the app waits for Break confirmation.

### Decisions (user, 2026-10-26)

- **Events that remove alerts:**
  - Starting Break, in the app or from the alert's OK, removes the delivered Focus alert.
  - Cancel and starting a new Focus remove all pending and delivered completion alerts. (Implemented: Focus start removes all delivered alerts but makes no pending-cancel call, because no pending request exists while idle and scheduling replaces one with the same identifier; see the implementation notes.)
  - Break completion removes a pending Break request but leaves a delivered Break alert alone. The next launch, activation, Focus start, or Cancel clears it. This avoids a banner that appears and vanishes within a second while the app is open.
- **Launch and activation clean up by phase.** On launch and on each foreground activation, after reconciling, the delivered Focus alert is removed unless the app is waiting for Break confirmation, and the delivered Break alert is removed unless Break is running. This also clears leftovers from before I10 and after a recovery reset. It needs no reading of Notification Center.
- **Stable identifiers.** Requests stay `focusComplete` and `breakComplete`. Only one cycle exists at a time, and a new request with the same identifier replaces the old one, so removal by the stable identifier is enough.
- **Validation:** agent-run unit tests, user-reported Cmd+U, and one manual Notification Center check. That check replaces the I10 stale-alert ToDo, which cannot be run as written once Cancel removes the old alert.

### Agent decisions within the user's choices (open to revision)

- **Boundary:** `NotificationScheduling` gains `removeDeliveredCompletion(for:)` and `removeAllDeliveredCompletions()`. `SystemNotificationScheduler` maps them to `UNUserNotificationCenter.removeDeliveredNotifications(withIdentifiers:)`. The recording test scheduler records them as new `Call` cases. The pending-request methods are unchanged.
- **Activation entry point:** a new `TimerStore` method, for example `activate()`, reconciles with the current time and then cleans up by phase. `FocusTimerApp` calls it on `scenePhase == .active` instead of `reconcileWithCurrentTime()`. `init` runs the same cleanup after its own reconcile. The one-second ticker keeps calling only `reconcileWithCurrentTime()`, so it never removes alerts.
- **Pause** keeps removing only the pending request. While a phase is running, no delivered alert for it should exist; pause at or after expiry is I12.
- **Repair and recovery** keep cancelling pending requests as today. The launch cleanup then removes delivered alerts by phase, so they need no separate call.
- **Focus completion** in the app removes nothing: the delivered Focus alert is the current one, and its OK must keep working.
- **Order in the OK path:** reconcile, validate the cycle ID (I10), start Break, then remove the delivered Focus alert. An ignored OK removes nothing, so a wrong-cycle tap cannot clear the current alert.
- **I10 ToDo:** when this phase is verified, the I10 spec's stale-alert ToDo is marked superseded by this phase's manual check, with a link here.

### Non-goals

- Cycle-scoped request identifiers, or reading delivered alerts from Notification Center.
- Pause at expiry, duplicate completion callbacks, and clock changes (I12).
- The completed state, Done, and Restart, and their notification actions (I13 to I17).
- Notification permission status and error guidance (I18).
- Changing the notification text, sound, category, or foreground presentation.

### Affected components

- `ios/FocusTimer/FocusTimer/NotificationScheduler.swift`: two removal methods on `NotificationScheduling` and `SystemNotificationScheduler`.
- `ios/FocusTimer/FocusTimer/TimerStore.swift`: removal calls on Break start, Break completion, Cancel, and Focus start; the activation method and the launch cleanup.
- `ios/FocusTimer/FocusTimer/FocusTimerApp.swift`: call the activation method on `scenePhase == .active`. Added during verification: the notification delegate runs on the main actor (crash fix; see the defect section).
- `ios/FocusTimer/FocusTimerTests/TestDoubles.swift`, `FocusTimerTests.swift`: new `Call` cases and tests. Existing tests that assert exact call lists (for example `[.cancelAll]` or `isEmpty` after launch) are updated for the new calls.
- `ContentView.swift`: no change expected.
- Docs after verification: [mission](../mission.md) notifications line and [tech stack](../tech-stack.md) gap note; the I10 ToDo as described above.

### Invariants to preserve

- A single authoritative timer state in `TimerStore`; alerts follow the state and never drive it.
- Explicit Break confirmation: removing alerts never starts or skips a phase, and the current Focus alert stays actionable while waiting.
- Local persistence through the injected `KeyValueStore`; cleanup writes nothing.
- Deadline-based recovery: cleanup runs after reconciliation and does not change deadlines.

## Plan

1. **Boundary**
   - [x] Add `removeDeliveredCompletion(for:)` and `removeAllDeliveredCompletions()` to `NotificationScheduling` and `SystemNotificationScheduler`; record them in `RecordingNotificationScheduler`.
2. **Event cleanup in `TimerStore`**
   - [x] Break start (in the app and from a matching OK) removes the delivered Focus alert.
   - [x] Break completion removes the pending Break request only.
   - [x] Cancel and Focus start remove all pending and delivered completions.
3. **Launch and activation cleanup**
   - [x] Add the activation method: reconcile, then remove the delivered Focus alert unless waiting for Break, and the delivered Break alert unless Break is running. Run the same cleanup at the end of `init`.
   - [x] Call it from `FocusTimerApp` on `.active`.
4. **Tests** (Swift Testing, recording scheduler)
   - [x] Each event above makes exactly the expected removal calls; Focus completion and pause make none for delivered alerts.
   - [x] An ignored OK (wrong cycle, no ID, duplicate) removes nothing.
   - [x] Launch and activation in each phase (idle, running Focus, paused Focus, waiting, running Break, paused Break) remove the right delivered alerts; the ticker's reconcile removes none.
   - [x] Existing I06 to I10 tests pass, updated where they assert exact call lists.
5. **Crash fix** (added during verification, 2026-10-26)
   - [x] Run the notification delegate methods on the main actor so tapping OK no longer crashes; record the defect and fix below.
   - [x] Re-run the Notification Center check to confirm.
6. **Docs**
   - [x] Record results here. Update the mission's notifications line and the tech-stack gap note.
   - [x] After the Notification Center check passes, mark the I10 stale-alert ToDo superseded by it.

## Validation

### Agent-run

Run after the Swift changes. Toolchain checks per `AGENTS.md` (`xcode-select -p`, `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list`). Then, from the repository root, on iPhone 17 Pro (iOS 26.5), not the user's simulator:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath /tmp/FocusTimerTests-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
```

Record `totalTestCount`, `passedTests`, `failedTests`, and expected failures from `xcrun xcresulttool get test-results summary --path <result bundle>`. Expected: the 80-function I10 baseline plus the new tests, all passing except the one I12 known issue (`pauseAtExpiryCompletesInsteadOfAddingTime`).

### User-reported (Xcode)

- Product > Test (Cmd+U) passes; report the summary line with the count.
- **Notification Center check** (iPhone 18 Pro Max, iOS 27.0, notifications allowed, Focus set to 1 min), replacing the I10 stale-alert ToDo:
  1. Start Focus and go to the home screen. Let the Focus alert appear; do not tap it.
  2. Open the app from the home screen. It waits for Break confirmation, and the Focus alert is still in Notification Center.
  3. Press Cancel. Expected: the Focus alert is gone from Notification Center.
  4. Start a new Focus and go to the home screen. When its alert appears, tap OK. Expected: the app opens, Break starts, and the Focus alert is gone.
  5. Go to the home screen and let Break finish. The Break alert appears. Open the app from the home screen. Expected: the app is idle and the Break alert is gone.

### Remains unverified

- Behavior on a physical device, and alert removal while the app is suspended (removal runs only when the app is active or launches).
- Other deferred OS rows from I02 (S1 to S3, the remaining N rows).

## Results

### Agent-run (2026-10-26)

- Toolchain: `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; Xcode 27.1; destination iPhone 17 Pro, iOS 26.5 (the user's iPhone 18 Pro Max was not used).
- First run (`/tmp/FocusTimerTests-20261026-213319.xcresult`): 94 tests, 1 failure, `delayedBreakReconciliationOnlyReturnsToIdle`. It expected Break completion to make no notification calls; it now makes one, `.cancel(phase: .runningB)`, by decision. The test was updated to expect exactly that call once.
- Final run (`/tmp/FocusTimerTests-20261026-213422.xcresult`): `** TEST SUCCEEDED **`. `xcresulttool get test-results summary`: result Passed, `totalTestCount` 94, `passedTests` 93, `failedTests` 0, `skippedTests` 0, `expectedFailures` 1 (`pauseAtExpiryCompletesInsteadOfAddingTime`, I12). That is the 80 I10 functions plus 14 new `TimerStoreAlertCleanupTests` functions.
- Build results: no compiler warnings.
- After the crash fix (`/tmp/FocusTimerTests-20261026-221251.xcresult`): `** TEST SUCCEEDED **`, result Passed, `totalTestCount` 94, `passedTests` 93, `failedTests` 0, `skippedTests` 0, `expectedFailures` 1 (I12). No compiler warnings.

### Implementation notes

- Focus start calls only `removeAllDeliveredCompletions()`. A pending-cancel call there would be redundant and would have changed the exact pending-call counts asserted by many I05 to I10 tests.
- `RecordingNotificationScheduler` has `pendingCalls` (schedule and cancel calls) and `deliveredCalls` (removals). Existing tests that assert exact call lists now read `pendingCalls`, because every `TimerStore` launch now records two delivered-alert removals. The new suite asserts the full `calls` list where order matters.
- `FocusTimerApp` calls `TimerStore.activate()` on `.active`; the one-second ticker still calls only `reconcileWithCurrentTime()`, which removes nothing (tested).

### User-reported

- 2026-10-26, Cmd+U in Xcode 27.1 (iPhone 18 Pro Max simulator, iOS 27.0): "Test run with 94 tests in 7 suites passed after 0.024 seconds with 1 known issue", as reported by the user.
- 2026-10-26, Notification Center check (iPhone 18 Pro Max, iOS 27.0): **the app crashed at step 4** when the user tapped the new Focus alert's OK from the home screen. Results for steps 1 to 3 were not reported. Console: `NSInternalInconsistencyException`, "Call must be made on main thread", thrown from `-[UIApplication _updateSnapshotAndStateRestorationWithAction:windowScene:]`, called from the completion of `AppDelegate.userNotificationCenter(_:didReceive:)` in `FocusTimerApp.swift`.

- 2026-10-26, after the crash fix, on the iPhone 18 Pro Max (iOS 27.0): the user reported Cmd+U with the expected results, then ran the Notification Center check steps 1 to 5 again with no crash and every step as expected: the Focus alert stayed while waiting, Cancel removed it, the new Focus alert's OK opened the app and started Break and the alert was gone, and opening the app after Break ended showed idle with the Break alert gone.

### Defect: notification OK crashes the app (found 2026-10-26)

- **Cause (agent analysis, confirmed by the fix and the re-run below):** the delegate's async `didReceive` is `nonisolated`. After `await TimerStore.shared.startBreakFromNotification(...)` returns, the rest of the method, and the system completion handler the Swift thunk calls when it ends, run off the main thread. UIKit asserts that this completion runs on the main thread.
- **Not caused by I11 or I10:** the same `nonisolated` async method with the `await` has existed since the app was added (`f646069`). The OK tap was never exercised before: I02 deferred the notification rows (N1 to N8), and I01 checked the in-app flow only.
- **Impact:** tapping OK on a Focus alert crashes the app. Unit tests call `startBreakFromNotification` directly, so they do not cover the delegate.
- **Decision (user, 2026-10-26):** fix it in this phase, because it blocks I11's Notification Center check, and record the details here for the history.
- **Fix (`FocusTimerApp.swift`):**
  - `AppDelegate` now conforms with `@preconcurrency UNUserNotificationCenterDelegate`.
  - Both delegate methods, `willPresent` and `didReceive`, dropped `nonisolated`. With the app target's default main-actor isolation they now run on the main actor, so they finish on the main thread, and so does the system completion handler that the Swift async thunk calls when they return.
  - `didReceive` calls `TimerStore.shared.startBreakFromNotification(cycleID:)` directly, without `await`, since both are on the main actor.
  - `willPresent` changed the same way for consistency. It had not crashed, but its completion was also reached off the main thread.
  - A comment above the class explains why the methods are main-actor isolated.
- **Alternatives considered:** keep the methods `nonisolated` and use the completion-handler variants, calling the handler from a main-actor task. The SDK's handler is not marked `Sendable`, so Swift 6 would need an unsafe capture to move it to the main actor. The main-actor conformance is smaller and needs no unsafe code.
- **Residual risk:** `@preconcurrency` makes Swift check at run time that UserNotifications calls these methods on the main thread. If it ever called them on another thread, the app would stop with an isolation error. The manual check exercises this path.
- **Verification:** the build and the 94 unit tests pass after the fix (agent-run, below). The unit tests cannot cover the delegate; the user's re-run of the Notification Center check (below) showed no crash.
