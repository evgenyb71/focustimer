# I16 Add notification Done

Status: verified

## Goal

The Break alert ("Cycle complete") gains a Done action. Pressing it ends the finished cycle as the in-app Done does ([I14](I14-in-app-done.md)), without opening the app. Both alerts also get wording that matches the app and no longer promises a button the collapsed alert does not show.

Roadmap exit check: a valid Break completion notification routes to Done; stale and duplicate actions are ignored, including an action after a launch reset ([I15](I15-in-app-restart.md)).

## Decisions

User, 2026-11-09:

- **Done stays closed:** the action ends the cycle in the background, and the alert goes away. The app is not brought up. The next open shows "Ready".
- **Alert wording:**

  | Alert | Title | Body |
  | --- | --- | --- |
  | Focus | Focus complete | Open the app or choose OK to start Break. |
  | Break | Cycle complete | Choose Done to finish, or open the app to restart. |

  The titles match the in-app headlines. The wording can still change before the build.
- **Checks:** Cmd+U and the manual alert check below.

Agent decisions, open to revision:

- **Model:** a cycle-checked store method beside `startBreakFromNotification`. It ignores an action whose cycle ID does not match the current cycle, then reconciles, then calls `done()`, which acts only in completed. The check comes first so that a rejected action cannot reconcile a newer cycle; the Codex review found the opposite order, and the OK path now uses the same order. After a launch reset there is no cycle ID, so a leftover alert's Done changes nothing and makes no notification calls.
- **Effects:** the same as the in-app Done. The durations in memory are saved, the state becomes idle with no cycle ID, and pending and delivered alerts are removed. On a background launch, the durations in memory are the saved ones.
- **Background launch:** when the app was closed, iOS launches it in the background to handle Done, and the launch policy applies first. A Break that ended while closed reconciles to completed, and Done then ends it. A completed state saved before the close resets at launch, and the Done is ignored. Either way the app ends idle.
- **Action:** a new Break alert category with one action, "Done", with no foreground or authentication option. It is registered alongside the Focus category, because setting categories replaces the whole set. I17 can add Restart to the same category.
- **Older alerts:** a Break alert scheduled by an earlier build has no category, so it shows no Done. No migration; saved data and `schemaVersion` do not change.
- **Plain tap:** opening the app from the Break alert works as before.
- **Alert content:** both alerts are built in one `NotificationScheduler` function, so the tests check titles, bodies, categories, and cycle IDs without the system notification center.

## Non-goals

- Restart from the alert (I17).
- Permission status and failure guidance (I18).
- Changing in-app Done, the launch policy, or the Focus alert's OK behavior.
- Custom sounds, or actions on any other alert.

## Plan

Tick an item only when it is done.

- [x] Add the cycle-checked notification Done to `TimerStore`.
- [x] Register the Break alert category with its Done action, and give the Break request that category.
- [x] Route the Done action in the notification delegate.
- [x] Change both alert titles and bodies.
- [x] Add the Swift Testing tests listed under Checks.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] User: run Cmd+U and the manual alert check; record both in Results as user-reported.
- [x] Update the [mission](../mission.md) notification rules and "Still to build", and the [tech stack](../tech-stack.md) notes on categories.
- [x] Set `Status: verified` and move the roadmap row to Completed.
- [x] Open the PR; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run: `scripts/test.sh`, with Swift Testing tests covering:

- A matching Done in completed gives idle with no cycle ID, saves the state and durations, and removes pending and delivered alerts.
- A matching Done while Break has just ended in the background reconciles to completed and then ends the cycle.
- A Done from an earlier cycle, with no ID, or with an unreadable ID changes nothing and makes no notification calls.
- A second Done changes nothing.
- Done in idle, running, paused, and waiting changes nothing.
- After a launch reset, a Done with the finished cycle's ID changes nothing.
- After a Break that ended while closed, a launch followed by a matching Done gives idle.
- The Break alert content carries its category and the new wording, and the Focus alert keeps its category with the new wording, if the content can be tested without the system notification center.

The tests call the store, not the system delegate; the manual check covers the real action.

User-reported, in Xcode on the iPhone 18 Pro Max simulator (iOS 27.0):

- Cmd+U passes; report the summary line with the count.
- Manual alert check, notifications allowed, Focus and Break at 1 min. To show Done or OK, hold the alert until it expands. To close the app, swipe it away in the app switcher.
  1. Run Focus, go to the home screen, and let Focus end. The alert reads "Focus complete" with the new body. Expand it and press OK: the app opens with Break running.
  2. Go to the home screen and let Break end. The alert reads "Cycle complete" with the new body. Expand it and press Done: the app does not open, and the alert is gone. Open the app: "Ready", with the durations kept.
  3. Run a full cycle, but swipe the app away while Break runs. Let Break end, expand the alert, and press Done: the app does not open. Open it: "Ready".
  4. Run a cycle and let Break end with the app open: the banner appears over "Cycle complete". Expand the banner and press Done: the screen changes to "Ready".
  5. Run a cycle and let Break end with the app open. Swipe the app away, then press Done on the alert left in Notification Center. Open the app: "Ready". The launch reset made this Done stale; the screen looks the same as after a valid Done, so the unit tests show that it was ignored.

Stays unverified: behavior on a physical device; how long iOS gives a background launch to handle the action; a Break alert's Done on the lock screen; VoiceOver for the alert actions (I19).

## Results

Agent-run, 2026-11-09, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 190, passed 190, failed 0, skipped 0, expected failures 0
PASSED
```

That is the earlier 176 plus 14 new test functions; the count treats a parameterized test as one. `TimerStoreNotificationDoneTests` has 9, covering every store item under Checks. `NotificationSchedulerTests` has 5, covering the content of both alerts. No existing test changed. The first run did not compile: the new content tests needed `import UserNotifications` under member import visibility. That was a test-file fix, not an app change. The build log shows no warnings from the project's files.

The README line on unimplemented features no longer lists notification Done.

User-reported, 2026-11-09:

- Cmd+U: "all unit tests ... passed". The summary line with the count was not included.
- Manual alert check: all five steps passed, as the user reported ("all UI tests are passed"). The steps and the simulator were not reported individually. The user noted that running the scenarios at one-minute durations took a while.

Remaining limitations: behavior on a physical device; how long iOS gives a background launch to handle the action; a Break alert's Done on the lock screen; VoiceOver for the alert actions (I19). Step 5 shows the same screen as a valid Done, so only the unit tests show that the stale Done was ignored.

### Review

Codex review, posted on the PR, 2026-11-09, with its own `scripts/test.sh` run at total 190, passed 190, failed 0:

- **[P2] Validate the cycle ID before reconciling.** Fixed. `doneFromNotification` reconciled before checking the cycle. A Done from an old alert could therefore save a newer Break whose deadline had passed as completed and cancel its pending alert, or, after a backward clock jump, rewrite the newer deadline and reschedule the alert. It now checks the cycle first; reconciling keeps the cycle ID, so a valid Done after Break ends still works.
- **The same order in the OK path, found while fixing:** `startBreakFromNotification` had the same order since I10 and [I11](I11-clean-up-alerts.md), whose spec recorded "reconcile, validate the cycle ID". A stale OK could save a newer Focus as waiting, or reschedule it after a backward jump. It now uses the same order. This changes a recorded I11 decision.
- **Regression tests:** 5 new ones. Done from an old cycle with a newer expired Break, and after a backward jump; Done with no or an unknown ID on an expired Break; OK from an old cycle with a newer expired Focus, and after a backward jump. Each asserts no state change, no writes, and no notification calls. All 5 failed against the old order and pass with the fix.
- **One older test updated:** the I15 Restart test that a stale OK cannot start Break in the new cycle relied on the stale OK to reconcile the new Focus. It now reconciles explicitly first, and its assertion is unchanged.
- **Trailing blank line** at the end of this spec, flagged by `git diff --check`: fixed.

Agent-run after the fixes, 2026-11-09, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 195, passed 195, failed 0, skipped 0, expected failures 0
PASSED
```

The manual alert check was not rerun. Valid OK and Done behave as before, because reconciling keeps the cycle ID, and the rejected cases are what the new unit tests cover. The user approved the PR without screenshots, since the change is in notifications.

Codex re-review, posted on the PR, 2026-11-09: the finding is resolved, and it recommends merging, with its own `scripts/test.sh` run at total 195, passed 195, failed 0. Its one nonblocking note, that the PR description still gave the old order and 190 tests, was fixed in the description.
