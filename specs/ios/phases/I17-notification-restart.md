# I17 Add notification Restart

Status: verified

## Goal

The Break alert ("Cycle complete") gains Restart beside Done. Pressing it starts a new Focus, as the in-app Restart does ([I15](I15-in-app-restart.md)), without opening the app. Break still needs its own confirmation in the new cycle.

Roadmap exit check: a valid action starts one Focus; foreground, background, and relaunch paths are checked, including an action after a launch reset (I15).

## Decisions

User, 2026-11-09:

- **Restart stays closed:** like Done ([I16](I16-notification-done.md)), the new Focus starts in the background and the alert goes away. The Focus alert arrives when Focus ends, and opening the app shows Focus running with the correct time.
- **Alert wording:** the Break alert body becomes "Choose Restart for another Focus, or Done to finish." The title stays "Cycle complete". The buttons follow the app's order: Restart, then Done.
- **Checks:** Cmd+U and the manual alert check below, run with `scripts/debug-minute.sh 10`.

Agent decisions, open to revision:

- **Model:** a cycle-checked store method beside the Done one. It ignores an action whose cycle ID does not match, then reconciles, then starts Focus only if the cycle is completed. The cycle check is what stops a leftover alert after a launch reset, since the reset leaves no cycle ID. The completed check is a backstop that keeps the intent explicit, because the in-app start also works from idle.
- **Effects:** the same as the in-app Restart. The durations in memory are rounded, clamped, and saved; earlier pending and delivered alerts are removed; a new cycle ID is created; and one Focus alert is scheduled. Under a Debug short minute, Focus runs for the shortened length.
- **One Focus:** Restart replaces the cycle ID, so a repeated Restart, or a Done, from the same alert no longer matches and changes nothing.
- **Background launch:** when the app was closed, iOS launches it in the background, and the launch policy applies first. A Break that ended while closed reconciles to completed, and Restart starts Focus; the next launch restores that running Focus. A completed state saved before the close resets at launch, and Restart is ignored, so no Focus starts.
- **Scheduling from the background:** the Focus alert is requested while iOS gives the background launch a short time. The manual check confirms it arrives after a swipe-close.
- **Saved data:** no change, and no new `schemaVersion`.

## Non-goals

- Changing in-app Restart or Done, notification Done, the Focus alert, or the launch policy.
- Permission status and failure guidance (I18).
- Opening the app from Restart.

## Plan

Tick an item only when it is done.

- [x] Add the cycle-checked notification Restart to `TimerStore`, acting only in completed.
- [x] Add the Restart action to the Break alert category, before Done.
- [x] Route the Restart action in the notification delegate.
- [x] Change the Break alert body.
- [x] Add the Swift Testing tests listed under Checks.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] User: run Cmd+U and the manual alert check; record both in Results as user-reported.
- [x] Update the [mission](../mission.md) notification rules and "Still to build", and the [tech stack](../tech-stack.md) note on categories.
- [x] Set `Status: verified` and move the roadmap row to Completed.
- [ ] Open the PR; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run: `scripts/test.sh`, with Swift Testing tests covering:

- A matching Restart in completed starts one Focus: running, unpaused, a deadline at now + the Focus run length, and a new cycle ID. Durations are saved rounded and clamped. Earlier alerts are removed, then one Focus alert is scheduled with the new ID.
- A matching Restart after Break ended in the background reconciles to completed, then starts Focus.
- After a Break that ended while closed, a launch followed by a matching Restart starts Focus, and the next launch restores it.
- A Restart from an earlier cycle, with no ID, or with an unknown ID changes nothing and makes no notification calls, including while a newer Break has passed its deadline unreconciled.
- A repeated Restart, and a Done from the same alert after Restart, change nothing.
- After a launch reset, a Restart with the finished cycle's ID changes nothing and starts no Focus.
- A matching Restart in running, paused, or waiting changes nothing.
- The new Focus expires into waiting for Break and does not start Break by itself.
- With a short minute, the new Focus runs for the shortened length.
- The Break alert content carries the new body.

The tests call the store, not the system delegate, and cannot see the registered action list; the manual check covers the real buttons.

User-reported, in Xcode on the iPhone 18 Pro Max simulator (iOS 27.0):

- Cmd+U passes; report the summary line with the count.
- Manual alert check, notifications allowed, Focus and Break at 1 min, with short minutes on. To show the buttons, hold the alert until it expands. To close the app, swipe it away in the app switcher.
  1. Run the app from Xcode once and stop it. Run `scripts/debug-minute.sh 10`, then open the app from its icon.
  2. Run a cycle to Break in the background. When Break ends, the alert reads "Cycle complete" with the new body, and expanding it shows Restart, then Done. Press Restart: the app does not open. About 10 seconds later, the Focus alert arrives. Open the app: "Focus complete", with Start Break; Break has not started.
  3. Press Start Break, swipe the app away, and let Break end. Press Restart on the alert: the app does not open, and the Focus alert arrives about 10 seconds later. Open the app: "Focus complete".
  4. Run a cycle and let Break end with the app open. Expand the banner and press Restart: the screen shows Focus running, counting down from 00:10.
  5. Run a cycle and let Break end with the app open. Swipe the app away, then press Restart on the alert left in Notification Center. No Focus alert arrives within 30 seconds. Open the app: "Ready".
  6. Regression: let a Break end in the background and press Done on its alert: the app does not open. Open it: "Ready".
  7. Run `scripts/debug-minute.sh off`.

Stays unverified: behavior on a physical device; how long iOS gives a background launch, beyond what step 3 shows; Restart on the lock screen; VoiceOver for the alert actions (I19).

## Results

Agent-run, 2026-11-09, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 215, passed 215, failed 0, skipped 0, expected failures 0
PASSED
```

That is the earlier 203 plus 12 new test functions in `TimerStoreNotificationRestartTests`, covering every store item under Checks; the count treats a parameterized test as one. In `NotificationSchedulerTests`, the Break alert test now expects the new body and the action test also covers `RESTART`. The build log shows no warnings from the project's files.

While writing the tests it became clear that the completed check is a backstop, not the main guard: the cycle check alone rejects a Restart after a launch reset, and the in-app start already refuses running, paused, and waiting. The decision above now says so.

The README line on unimplemented features no longer lists notification Restart.

User-reported, 2026-11-09: Cmd+U and all seven steps of the manual alert check passed ("All pass"), with short minutes on. That covers Restart from the background, after a swipe-close with the Focus alert arriving, over the open app, a leftover alert after a reset starting no Focus, and Done still working. The Cmd+U summary line with the count, the individual steps, and the simulator were not reported.

Remaining limitations: behavior on a physical device; how long iOS gives a background launch, beyond what step 3 shows; Restart on the lock screen; VoiceOver for the alert actions (I19).
