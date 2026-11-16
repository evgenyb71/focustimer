# I27 Quiet completion alerts while the app is open

Status: verified

## Goal

When Focus or Break ends while the app is open, the user hears the alert sound but sees no banner, and nothing is added to Notification Center; the screen already changes to "Focus complete" or "Cycle complete". When the app is in the background or closed, alerts behave as before.

Roadmap exit check: with the app in the foreground, no banner or Notification Center entry appears, but the sound still plays; alerts in the background are unchanged. User-reported foreground and background alert check.

## Decisions

User, 2026-11-16 (raised during I19):

- **Foreground:** sound only. No banner and no Notification Center entry.
- **Background and closed:** unchanged, including the OK, Restart, and Done actions.
- **Placement:** its own phase after I19, rather than part of the accessibility work.
- **Checks:** Cmd+U, and a manual check with `scripts/debug-minute.sh 10` of Focus and Break ending with the app open and with it in the background.

Agent decisions, open to revision:

- **Where:** iOS asks the app how to present an alert only while the app is in the foreground, so the change is the presentation the notification delegate returns: sound alone instead of banner, list, and sound. No state check is needed in the app, and background delivery is untouched by design.
- **Testable constant:** the foreground presentation lives beside the other alert details in the notification scheduler, so a unit test pins it to sound only.
- **Screen update:** the in-app screen keeps changing on the next one-second tick, as today. Reconciling the moment the foreground alert arrives is possible but not needed.
- **Saved data:** no change, and no new `schemaVersion`.

## Non-goals

- Alert content, actions, sounds, or scheduling.
- A setting to choose the foreground behaviour.
- Haptics or an in-app sound when alerts are denied.

## Plan

Tick an item only when it is done.

- [x] Return sound-only presentation for alerts that arrive while the app is open.
- [x] Add a Swift Testing test for the foreground presentation.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] User: run Cmd+U and the foreground and background alert check; record in Results as user-reported.
- [x] Update the [mission](../mission.md) notification rules and "Still to build", and the [tech stack](../tech-stack.md) notification note.
- [x] Set `Status: verified` and move the roadmap row to Completed.
- [ ] Open the PR; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run: `scripts/test.sh`, with a test that the foreground presentation is sound only, without banner or list.

User-reported, in Xcode, with `scripts/debug-minute.sh 10`:

1. Cmd+U passes.
2. With the app open, let Focus end: the sound plays, no banner appears, Notification Center has no FocusTimer entry, and the screen shows "Focus complete".
3. Start Break and let it end with the app open: the same, with "Cycle complete".
4. Restart, go to the Home Screen, and let Focus end: the banner appears with OK, as before.
5. Open the app, start Break, go to the Home Screen, and let it end: the banner appears with Restart and Done, as before.

Stays unverified: a physical device; the foreground case with the device locked, where iOS treats the app as in the background.

## Results

Agent-run, 2026-11-16, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 258, passed 258, failed 0, skipped 0, expected failures 0
PASSED
```

The new test is in `NotificationSchedulerTests`. The agent did not exercise delivery itself; it cannot hear the simulator, so the alert checks are user-reported.

User-reported, 2026-11-16, on the user's simulator with `scripts/debug-minute.sh 10`: Cmd+U passed, and all five steps of the alert check passed. With the app open, Focus and Break ended with the sound only, no banner, and nothing in Notification Center, while the screen changed; in the background, the banners appeared with OK, and with Restart and Done, as before.

Remaining limitations: a physical device; the foreground case with the device locked.

### Review

Codex review: no correctness blockers; recommended merging. One nonblocking note, fixed: the extra blank line at the end of this spec. No code changed, so no checks were rerun.
