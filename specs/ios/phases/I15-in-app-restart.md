# I15 Add in-app Restart and the launch-state policy

Status: verified

## Goal

After Break, the "Cycle complete" screen offers Restart, which begins a new Focus straight away. Break still needs its own confirmation in the new cycle. The green Start Focus button already behaved this way (see [I14](I14-in-app-done.md)), so this part names the action and pins its behavior with tests.

The phase also sets what a relaunch shows. A timer that was working when the app closed keeps its state. An end screen the user already had when the app closed does not come back: the app opens on the initial screen.

Roadmap exit checks:

- I15: Completed → new Focus with saved durations and new cycle identity; Break still needs confirmation.
- I22, absorbed here and removed from the [roadmap](../roadmap.md): record in the mission whether each state is restored or reset on relaunch, with behavior matching for every state, tests, and a manual relaunch check.

## Decisions

User, 2026-11-05, for Restart:

- **Label:** the primary button on "Cycle complete" reads "Restart" instead of "Start Focus". It stays green and primary, with Done below it. The message becomes "Restart for another Focus, or press Done to finish."
- **Durations:** the steppers stay editable in completed. Restart uses the durations on screen, rounded, clamped, and saved, as Start and Done do. This refines the exit check's "saved durations" to "the durations shown", because an edit is saved at the moment Restart starts it.

User, 2026-11-05, for the launch-state policy, after checking Restart:

| Saved state when the app launches | On launch |
| --- | --- |
| Running, deadline still ahead | Restored, with the correct time left |
| Paused | Restored, with the same time left |
| Running, deadline passed while closed | The end screen shows once; the next launch resets |
| Waiting for Break confirmation | Reset to the initial screen |
| Completed | Reset to the initial screen |

- **Why:** closing a working timer should keep it. Once a stage is done, the next start should show the initial state, not Restart or Start Break.
- **Durations on reset:** the last saved durations stay. Edits made on an end screen and not started are lost when the app closes.
- **Phase:** this lives in I15 and closes I22, in one PR.

This reverses two earlier decisions: [I13](I13-completed-state.md) restored completed on relaunch, and the mission's invariant says "Done and Restart remain available after relaunch in completed". The mission's invariant and behavior sections now state the new policy. Break confirmation is not weakened: a reset ends the cycle, so Break never starts without confirmation.

Agent decisions, open to revision:

- **Restart model:** no new `TimerStore` method. `startFocus()` already acts in completed and does nothing once Focus runs, so a repeated Restart cannot start a second phase. I17 can add a cycle-checked notification path, as `startBreakFromNotification` does for Break.
- **Reset model:** the launch code looks at the saved phase before reconciling the deadline. A saved waiting or completed state becomes a fresh idle state and is saved; a running phase then reconciles as it does today. That is how an expiry while closed still shows its end screen once. Returning from the background is not a launch and keeps every state.
- **Effects of a reset:** as Done, pending and delivered alerts are removed and there is no cycle ID. It shows no correction notice, because nothing was wrong. A repair notice from the same launch still shows.
- **Saved format:** no change, and no new `schemaVersion`.
- **Accessibility:** the button uses its visible label, "Restart".

Limitations of this policy, worth revisiting if they cause surprises:

- **iOS ending the app:** a launch cannot tell whether the user closed the app or iOS ended it while suspended. If the user leaves on an end screen and iOS ends the app, the next open also shows the initial screen.
- **The Focus alert after a close:** when Focus ended while the app was closed, the launch keeps the cycle. A plain tap on the alert opens "Focus complete", waiting for Start Break, which the user confirmed as correct. The OK button, shown only when the alert is expanded, starts Break; see [Results](#launch-state-policy).
- **A leftover Focus alert:** if the user saw "Focus complete" in the app, closed it, and then pressed OK on an alert still in view, the app opens on the initial screen and Break does not start. The launch removes that alert, but the press itself is the launch.
- **I16 and I17:** the same applies to Break alert actions. Those phases need to treat an action after a reset as stale, and their relaunch checks should cover it.

## Non-goals

- Notification Done or Restart (I16, I17); the Break alert gains no action here.
- Changing Start in idle, Done, Cancel, or which phases allow editing.
- Restyling the end screens.
- Telling a user's close apart from iOS ending the app; the system gives no reliable signal for it.

## Plan

Tick an item only when it is done.

Restart:

- [x] Change the completed button title and status message in `TimerStore`.
- [x] Update the existing end-state tests that expect "Start Focus".
- [x] Add the Swift Testing tests listed under Checks, in a new `TimerStoreRestartTests` suite.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] Take a simulator screenshot of "Cycle complete" for the PR.
- [x] User: run Cmd+U and the Restart manual check; record both in Results as user-reported.

Launch-state policy:

- [x] Reset a saved waiting or completed state at launch, before reconciling, and remove pending and delivered alerts.
- [x] Update the existing tests that expect these states to survive a relaunch, and move the relaunch-into-completed Done and Restart tests to the new behavior.
- [x] Add the launch-policy tests listed under Checks, in a new `TimerStoreLaunchPolicyTests` suite.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] User: run Cmd+U and the launch-policy manual check; record both in Results as user-reported.

Record and review:

- [x] Update the [mission](../mission.md) for what is decided: Restart exists and uses the durations shown, and the rewritten relaunch invariant, with the reset marked as not yet built under "Still to build".
- [x] Update the [roadmap](../roadmap.md): the new I15 title and exit check, the I22 row removed, and the stale-action note on the I16 and I17 rows.
- [x] Update the [README](../../../README.md) line that called Done and Restart unimplemented.
- [x] Once the reset is built, update the mission's saved-data and notification rules for launch, and remove the reset from "Still to build".
- [x] Update the [tech stack](../tech-stack.md) design notes for `cycleID` and the launch reset.
- [x] Set `Status: verified` and move the I15 row to Completed.
- [x] Open the PR; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run: `scripts/test.sh`, with Swift Testing tests covering:

Restart, in `TimerStoreRestartTests` (the relaunch test changes with the policy):

- Restart from completed runs Focus with a deadline at now + the Focus duration, unpaused, with a cycle ID different from the finished cycle's.
- Restart saves edited durations rounded and clamped, so a relaunched store loads them.
- Restart removes the earlier pending and delivered alerts, then schedules one Focus alert carrying the new cycle ID.
- A repeated Restart keeps the running Focus: same deadline and cycle ID, and no extra notification calls.
- The new Focus expires into waiting for Break, and does not start Break by itself.
- A Focus alert from the finished cycle cannot start Break in the new cycle.
- Completed shows the title "Restart" and the new message; Start in idle and Start Break keep their titles.

Launch policy, in `TimerStoreLaunchPolicyTests`:

- A saved waiting state and a saved completed state launch into idle with no cycle ID, no deadline, and no notice. The idle state is saved, and pending and delivered alerts are removed.
- The saved durations survive that reset, and an unstarted edit made on an end screen does not.
- A running phase with its deadline ahead, and a paused phase, restore unchanged at launch with their alerts kept as today.
- Focus and Break deadlines that passed while closed launch on their end screens with the cycle ID kept. A second launch resets each one.
- At the store level, an OK for that cycle after Focus expired while closed starts Break. An OK with that cycle's ID after a reset does nothing. These tests call `startBreakFromNotification` directly, not the system delegate.
- Activation in the same process keeps the waiting and completed states.
- A repaired saved state keeps its notice through the reset.
- After a reset, a new Focus still gets a new cycle ID and waits for Break confirmation.

User-reported, in Xcode on the iPhone 18 Pro Max simulator (iOS 27.0):

- Cmd+U passes; report the summary line with the count.
- Launch-policy manual check, notifications allowed, Focus and Break at 1 min unless a step says otherwise. To close, swipe the app away in the app switcher. To open, use the home screen icon, not Cmd+R.
  1. Let Focus end with the app open. Close and open: "Ready", with Start. The Focus alert is gone from Notification Center.
  2. Set Focus to 2 min and run a full cycle to "Cycle complete". Change Break to 3 min without starting. Close and open: "Ready", with Start and no Restart or Done. Focus shows 2 min and Break shows 1 min, because the edit was not started. The Break alert is gone.
  3. Start Focus, close, and open before it ends: Focus is running with the correct time left. Pause, close, and open: paused with the same time left. Cancel with ×.
  4. Start Focus, close, wait past its end, and open with the icon: "Focus complete" with Start Break. Close and open again: "Ready".
  5. Start Focus, close, wait for the alert, and tap the alert itself: the app opens on "Focus complete", waiting for Start Break. Start Break, let it end while closed, then open: "Cycle complete". Press Restart: Focus runs, and Break still needs confirmation. As first written, this step said to press OK and expected Break to be running; the user tapped the alert instead.
  6. Start Focus, close, wait for the alert, expand it, and press OK: the app opens with Break running.

Stays unverified: behavior on a physical device; iOS itself ending a suspended app, which the manual check approximates with a swipe; VoiceOver and Dynamic Type for the renamed button (I19).

## Results

### Restart

Agent-run, 2026-11-05, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 156, passed 156, failed 0, skipped 0, expected failures 0
PASSED
```

That is the earlier 147 tests plus 9 in the new `TimerStoreRestartTests`. Three existing tests in `TimerStoreEndStateTests` changed, and only their expected title and message text. That suite keeps the checks of the completed title and message, and of Start and Start Break. `TimerStoreRestartTests` also covers Restart clearing a correction notice, which the Checks list did not name.

The tests cover the store, not the view. Screenshot, agent-run on iPhone 17 Pro, iOS 26.5, with a seeded completed state: "Cycle complete" shows the new message, Restart, and Done below it, with no ×. The file is kept outside the repository; the user attached it to the PR.

User-reported, 2026-11-05:

- Cmd+U: "Test run with 156 tests in 12 suites passed after 0.034 seconds."
- Restart manual check, the first version of this spec: "All steps verified". The user did not list the steps or the simulator individually. Its step 4, relaunching into "Cycle complete" and pressing Restart, showed the behavior this phase now removes, and that observation led to the launch-state decision.

### Launch-state policy

Agent-run, 2026-11-05, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 176, passed 176, failed 0, skipped 0, expected failures 0
PASSED
```

The first run, with only the reset and the new `TimerStoreLaunchPolicyTests`, had 15 failures, all in older tests:

- **Reversed by this decision, expectations changed:** the tests that restored waiting or completed on relaunch, in the completed-state, end-state, and transition suites. The completed-state repair tests now expect a reset with the notice.
- **Done and Restart after a relaunch:** both now start from a Break that expired while closed.
- **Kept their purpose with another fixture:** the 2 → 3 migration test and the cycle ID relaunch test now use a running phase. The waiting case of the launch alert-cleanup test moved to the new suite. The unversioned, version 1, and stray-field tests kept their other cases, and their waiting case became a separate test of the reset.
- **Done and Restart clearing a notice:** the fixture no longer reached completed, so it now uses a Break that expired while closed with an unreadable `config`, and the tests assert completed first.

The new suite also checks that a launch after an expiry while closed keeps that phase's alert, which the Focus alert's OK depends on.

Agent-run in the real app on the same simulator, with a saved completed state seeded before launch: the app opened on "Ready" with Start, and the saved state read afterwards was idle. Seeding cannot reproduce the swipe, alert, or expiry-while-closed steps, so those stay with the user's manual check.

User-reported, 2026-11-05:

- Cmd+U: "Test run with 176 tests in 13 suites passed after 0.042 seconds."
- Launch-policy manual check: "Everything works fine", with one difference in step 5. After a close, the app opened with Break waiting to start, not running. The user then confirmed they had tapped the alert itself, not OK, which is the expected result of a plain tap ([I02](I02-exercise-lifecycle-notifications.md)). The user called this behavior correct, so step 5 now describes the plain tap and no code changed. The simulator for the check was not stated; the user's later screenshot of the alert shows the iPhone 18 Pro Max, iOS 27.0.

- Step 6, the expanded OK button after a close, run after the user found the button: Break runs, as the user reported ("Yes, Break runs"). This is the first check of OK after a close; [I11](I11-clean-up-alerts.md) checked it from a suspended app. The check was on the same simulator as the screenshot, as far as reported.

Remaining limitations: behavior on a physical device; iOS itself ending a suspended app; VoiceOver and Dynamic Type for the renamed button (I19).

### Review

Codex review, posted on the PR, 2026-11-05: recommended merging from a correctness perspective, with no blocking findings, and its own `scripts/test.sh` run at total 176, passed 176, failed 0. It had one documentation note: the mission said a plain alert tap after a close opens "Focus complete", which holds only when Focus ended while closed. Fixed by stating both cases; docs only, so no test rerun.

The user attached the "Cycle complete" and launch-reset screenshots to the PR.
