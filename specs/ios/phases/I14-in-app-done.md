# I14 Add in-app Done

Status: verified

## Goal

After Break, the "Cycle complete" screen offers Done, which ends the cycle and returns to idle. Until now the only ways out of completed were Start Focus and × (see [I13](I13-completed-state.md)).

Roadmap exit check: Completed → idle; configuration survives; repeated Done is harmless.

## Decisions

User, 2026-11-05:

- **Placement:** a secondary bordered "Done" button below the green Start Focus button, shown only in completed. Start Focus stays the primary action until I15 turns it into Restart.
- **× is hidden in completed.** Done is the one way to end a finished cycle. The header keeps × in every other phase. `cancel()` itself does not change, so the mission's "Cancel returns to idle from any phase" is reworded to match what the screen offers.
- **Done saves the durations.** Edits made on the "Cycle complete" screen are rounded, clamped, and saved, so they survive a relaunch from idle. The mission's "persist when Focus starts" gains "or on Done". Saved format and `schemaVersion` do not change.

Agent decisions, open to revision:

- **Model:** a `done()` method on `TimerStore` that acts only in completed. In any other phase, including after an earlier Done, it does nothing: no state write, no save, and no notification calls.
- **Effects:** the state becomes a fresh idle `TimerState` with no cycle ID, the notice clears, and pending and delivered alerts are removed, as Cancel does. Removing pending requests covers the case noted in `startFocus()`, where a request can outlive the state.
- **After Done:** the normal idle screen ("Ready"), with durations still editable.
- **Saved completed state:** Done works the same after a relaunch into completed, as the mission's invariants require.
- **Accessibility:** the button uses its visible label, "Done". Removing × from the completed header leaves Done as the VoiceOver path out, so no extra label is needed.

## Non-goals

- Restart (I15) and notification Done or Restart (I16, I17); the Break alert gains no action here.
- Changing what Start Focus does in completed.
- Changing Cancel or × in any other phase, or Cancel's behavior of not saving edits.
- Restyling the end screens, and the launch-state policy for other states (I22).

## Plan

Tick an item only when it is done.

- [x] Add `done()` to `TimerStore`: acts only in completed, saves the rounded and clamped durations, returns to idle, and removes pending and delivered alerts.
- [x] Show the Done button below Start Focus, only in completed.
- [x] Hide × in completed.
- [x] Add the Swift Testing tests listed under Checks.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] User: run Cmd+U and the manual check; record both in Results as user-reported.
- [x] Update the [mission](../mission.md) for Done, × in completed, and when durations are saved.
- [x] Set `Status: verified` and move the roadmap row to Completed.
- [ ] Open the PR; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run: `scripts/test.sh`, with new Swift Testing tests covering:

- Done from completed gives idle with no cycle ID, no deadline, and no notice, and the state is saved.
- Done keeps the durations, and saves edited durations rounded and clamped, so a relaunched store loads them.
- Done removes pending and delivered alerts.
- A second Done, and Done in idle, running, paused, and waiting, change nothing and make no notification calls.
- Relaunch into completed, then Done, gives idle; relaunch after Done stays idle.
- A new Focus after Done still waits for Break confirmation.

User-reported, in Xcode on the iPhone 18 Pro Max simulator (iOS 27.0):

- Cmd+U passes; report the summary line with the count.
- Manual check, notifications allowed, Focus and Break at 1 min:
  1. Run Focus, press Start Break, go to the home screen, and let Break end. The Break alert appears.
  2. Open the app: "Cycle complete" shows Start Focus and Done, with no ×.
  3. Change a duration and press Done: the idle screen shows the edited durations, × is back, and the Break alert is gone from Notification Center.
  4. Stop the app and open it again: still idle, with the edited durations.

Stays unverified: behavior on a physical device; VoiceOver and Dynamic Type for the new button (I19).

## Results

Agent-run, 2026-11-05, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 147, passed 147, failed 0, skipped 0, expected failures 0
PASSED
```

That is the earlier 135 tests plus 12 in the new `TimerStoreDoneTests`. No existing test needed changes. The first run had 1 failure, in the new `doneClearsACorrectionNotice`: its fixture left out `schemaVersion`, so the record was migrated without a notice. The fixture was fixed, not the app code.

The tests cover `canFinish` and `canCancel`, not the view; the user-reported manual check covers the Done button and the hidden ×.

User-reported, 2026-11-05:

- Cmd+U: reported "done and correct"; the summary line with the count was not included.
- Manual check: reported "all good". The user did not list the steps or the simulator individually.

Remaining limitations: behavior on a physical device; VoiceOver and Dynamic Type for the new button (I19).
