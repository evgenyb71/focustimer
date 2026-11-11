# I18 Show permission status and failure guidance

Status: verified

## Goal

When alerts are denied, the app says so in one line and tells the user where to turn them on. If iOS rejects an alert request while alerts are allowed, the app shows a notice instead of failing silently. Neither case blocks the timer: Focus, Break confirmation, Restart, and Done all work in the app.

Roadmap exit check: denied alerts and scheduling errors do not block timer flow; Settings guidance is available.

## Decisions

User, 2026-11-11:

- **Denied status:** a one-line hint, shown only while alerts are denied, telling the user to turn on alerts in Settings. No button.
- **Permission request:** unchanged; the app still asks at launch.
- **Scheduling error:** if adding an alert fails while alerts are allowed, the existing notice line shows that the end-of-phase alert could not be scheduled and the app should stay open to see the end. It clears on the next transition, as the repair notice does. It is not shown when alerts are simply denied, since the hint covers that.
- **Checks:** Cmd+U and the manual deny/allow check below.

Agent decisions, open to revision:

- **Status source:** the permission status is read through the notification boundary at launch and on each activation, so the hint disappears after the user turns alerts on in Settings and returns. Tests use the recording scheduler with a settable status.
- **Which statuses count as denied:** only `denied`. `notDetermined` shows nothing, since the launch prompt is pending; `authorized`, `provisional`, and `ephemeral` show nothing.
- **Error reporting:** the scheduler reports an add failure back to `TimerStore` on the main actor. A failure that arrives after the phase it belonged to has ended (another transition, or a newer cycle) is ignored, so a late error cannot show a notice for a different phase.
- **Hint placement and wording:** under the controls, in secondary footnote text with a `bell.slash` symbol, in every phase: "Alerts are off, so you won't be told when a phase ends. Turn them on in Settings > Notifications > FocusTimer."
- **Notice wording:** "The end-of-phase alert couldn't be scheduled. Keep the app open to see when it ends."
- **Denied failures:** an add error of `notificationsNotAllowed` is not reported, and the store also ignores failures while it knows alerts are denied.
- **After the launch prompt:** the permission is read again when the user answers, so a denial shows the hint without waiting for the next activation.
- **Saved data:** no change, and no new `schemaVersion`. Permission status is not saved.

## Non-goals

- An Open Settings button, or asking for permission later than launch.
- Surfacing failures of removal calls, or of the category setup.
- Changing alert content, actions, or the launch policy.
- Accessibility review of the new text beyond a label check (I19).

## Plan

Tick an item only when it is done.

- [x] Add the permission status read and the add-failure report to the notification boundary and `SystemNotificationScheduler`.
- [x] Track the denied status in `TimerStore`, refreshed at launch and on activation.
- [x] Show the scheduling-failure notice in `TimerStore`, ignoring failures for a phase that has ended.
- [x] Show the denied hint in `ContentView`.
- [x] Extend the recording scheduler and add the Swift Testing tests listed under Checks.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] User: run Cmd+U and the manual check; record both in Results as user-reported, with a screenshot of the hint.
- [x] Update the [mission](../mission.md) notification rules and "Still to build", and the [tech stack](../tech-stack.md) note on failures.
- [x] Set `Status: verified` and move the roadmap row to Completed.
- [ ] Open the PR; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run: `scripts/test.sh`, with Swift Testing tests covering:

- Denied status shows the hint; `notDetermined`, `authorized`, and `provisional` do not.
- A status change from denied to authorized, seen on activation, removes the hint, and the reverse adds it.
- With alerts denied, a full Focus → Start Break → completed → Restart and Done flow runs in the app as usual.
- An add failure for the current phase and cycle shows the notice; the timer keeps running with its deadline.
- An add failure that arrives after a transition or for an earlier cycle shows nothing.
- The notice clears on the next transition.

User-reported, in Xcode:

- Cmd+U passes.
- On a fresh simulator install with `scripts/debug-minute.sh 10`: deny the launch prompt and see the hint; run Focus → Start Break → completed in the app; turn on alerts in Settings, return, and see the hint gone; run Focus and receive its alert. Take a screenshot of the hint for the PR.

Stays unverified: the scheduling-failure notice in a real app, since iOS offers no simple way to make an add fail; it is covered by unit tests only. Behavior on a physical device.

## Results

Agent-run, 2026-11-11, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 232, passed 232, failed 0, skipped 0, expected failures 0
PASSED
```

New tests are in `TimerStoreAlertPermissionTests` and `NotificationSchedulerTests`. Writing `try #require(x)()` on one line crashed the Swift compiler in the test target, so the tests bind the handler first.

User-reported, 2026-11-11, iPhone 18 Pro Max simulator, iOS 27.0, with `scripts/debug-minute.sh 10`:

- Cmd+U: all tests pass.
- The first run went over an existing install whose alerts were already denied, so iOS showed no prompt; the hint was shown. After removing the app and running it again, the launch prompt appeared and the rest of the manual check behaved as expected: denying showed the hint, the in-app cycle ran, turning alerts on in Settings removed the hint, and the Focus alert arrived. The user supplied a screenshot of the hint in idle for the PR.

Remaining limitations: the scheduling-failure notice is covered by unit tests only. Not checked on a physical device. iOS asks only once per install, so a user who denied alerts sees only the hint and must use Settings.

