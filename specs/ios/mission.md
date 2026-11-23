# iOS mission

## Purpose and boundaries

A small, reliable offline iPhone timer for Focus followed by an explicitly confirmed Break. Remaining time stays correct across suspension and relaunch using persisted deadlines and local notifications. The app stays usable when notifications are denied; sound and delivery timing are subject to system settings.

Native SwiftUI, iPhone-only portrait, iOS 26 minimum. No accounts, analytics, cloud sync, network backend, shared cross-platform code, or Chrome changes. App Store delivery is a later possibility, not a committed target.

Planned direction: Focus stays a plain timer, and Break can optionally guide the user through their own exercises. See [Guided Break](#planned-guided-break-not-built); none of it exists yet.

## Current behavior

- **Durations:** defaults are one minute each. Whole-minute steps: Focus 1–240 minutes, Break 1–120 minutes. Saved and started durations are rounded and clamped to the same ranges. They can be edited only in idle and completed, and persist when Focus starts or on Done.
- **Flow:** `idle → runningA → waitingForAConfirm → runningB → completed`. Pause is a flag on either running phase. Break never starts automatically. From completed, Done returns to idle and Restart begins a new cycle with the durations shown; repeating either changes nothing. Cancel (×) returns to idle from every other phase and keeps the configuration; it is not offered in completed.
- **Saved data:** configuration and timer state are saved locally with a schema version. Running phases save absolute deadlines; paused phases save remaining seconds. Older versions migrate at launch and keep their data, apart from the relaunch reset below. Invalid saved state is repaired with a correction notice. An unreadable record is replaced with defaults or idle, with the same notice, and the other record is kept. A newer or unreadable version loads defaults and is replaced on the first save.
- **Relaunch:** a running phase and a paused phase are restored. A phase whose deadline passed while the app was closed shows its end screen once. A saved waiting or completed state resets to idle at launch with no notice, keeping the saved durations and removing alerts; edits not yet started are lost. A launch cannot tell the user's close from iOS ending the app. Returning from the background is not a launch.
- **Time:** the countdown updates once per second in the foreground. Launch and activation reconcile expired deadlines. Pausing at or after expiry completes the phase. After a backward clock jump, a deadline more than the phase's length away moves to now + that length, with no notice. A forward jump completes the phase on the next reconcile and never skips Break confirmation. A saved paused time longer than the phase is clamped at launch with the notice.
- **Notifications:** completion alerts use the default sound. When a phase ends while the app is open, only the sound plays: no banner and no Notification Center entry, since the screen already shows the end. Each Focus → Break cycle has a saved cycle ID that alerts carry. The Focus alert's OK opens the app and starts Break only for the matching cycle; a stale, missing, or repeated action changes nothing, and that includes an action after a relaunch reset. OK appears only when the alert is expanded. A plain tap on the alert opens the app without starting Break. If Focus ended while the app was closed, it opens "Focus complete" and waits for Start Break; if the app was already waiting for Break when it closed, the launch resets to idle. The Break alert offers Restart and Done, which act as the in-app buttons do, without opening the app, only for the matching completed cycle; a stale, missing, or repeated action, or one after a relaunch reset, changes nothing, and Restart never starts more than one Focus. When the app is closed, iOS launches it in the background for them, and the relaunch rules apply first. Alert titles match the in-app headlines, "Focus complete" and "Cycle complete". Pending requests are removed on pause and cancel. Permission is requested at launch. While alerts are denied, a one-line hint under the controls points to Settings; it is rechecked when the prompt is answered and on each activation. If iOS rejects an alert request for another reason, the status line says the alert could not be scheduled until the next transition or the phase ends; a failure for a run that has already ended is ignored. Neither blocks the timer. Delivered alerts are removed once they no longer match the timer: starting Break removes the Focus alert, and Cancel, Done, or a new Focus removes all. Launch and activation keep the Focus alert only while waiting for Break, and the Break alert only while Break runs or the cycle is completed.
- **UI:** warm card-based design with native symbols and accessibility labels for pause and cancel. Light and dark themes share one palette that meets WCAG AA contrast in both. Text scales to the largest accessibility size: the header buttons move above the title and the steppers sit under their labels. A running Focus is teal and a running Break is sage: the status card shows the phase name, a symbol, "Running", and the time in that colour, and the matching duration row is highlighted. Paused keeps the colour, lighter, with a pause symbol and "Paused". VoiceOver reads the card as the phase, running or paused, and the time left; the idle card reads "No timer running", and the duration rows read their minutes. Focus end is amber with a cup, "Focus complete", and Start Break. Break end is green with a checkmark, "Cycle complete", Restart, and Done. The app icon shows two overlapping timer rings, teal Focus behind sage Break, with light, dark, and tinted versions.

Not yet verified: behavior on a physical device, and the deferred suspension checks from [I02](phases/I02-exercise-lifecycle-notifications.md).

## Planned: Guided Break (not built)

Stage 2 adds an optional guided routine inside Break. Focus stays a plain timer. This section records the user's intent and decisions of 2026-11-23; it does not describe built behavior. The current behavior and invariants above stay in force until a verified phase changes them.

The [Stage 2 roadmap](roadmap.md#stage-2-guided-break) starts with product design in I36. Detailed decisions belong to the phase that needs them; preparing this roadmap does not settle them.

### Request

After a Focus session, the user can follow a sequence of activities they define themselves, such as 45 minutes of studying followed by a 15-minute Break with stretches and rest. Each activity has user-written text and timing expressed as a total duration, repetitions, a duration per repetition, or a supported combination. The app guides the user through the sequence.

Whether this is configured in Settings, on the main screen, or through another flow is a design question. Plan broad phases first, then agree each phase's settings and behavior before building it.

The user's example items, spelling corrected:

- "Stretch your neck, move it back to the max. Hold for 5 secs, do it 10 times"
- "Stretch your shoulders, move them up, repeat 10 times"
- "Move your left hand down, hold for 5 secs, repeat 10 times"
- "Relax for 30 secs"
- and so on

### Terms

- **Step:** one activity, such as a stretch or a rest, with a name the user writes.
- **Routine:** a named, ordered list of steps.
- **Repetition:** one of several equal parts of a step. **Hold:** the seconds a position is kept in each repetition.
- **Guided Break:** a Break that follows a routine. **Plain Break:** today's Break.
- **Timer pause:** the user's Pause action stops the countdown; Resume creates a new deadline from the remaining time, as it does today.
- **Between-repetition pause:** a timed gap inside a routine, which uses Break time while the timer is running. Gaps between sides or before steps, if supported, also use Break time; their rules are left for design.
- **Rest after the routine:** the remaining Break time once the routine finishes. A user-written rest step such as "Relax for 30 secs" is part of the routine instead.
- **Fixed Break duration:** the configured countdown duration, including routine steps, timed gaps, and rest afterward. Time spent in a user-initiated timer pause does not consume it, so the wall-clock finish can move later on Resume.

### User direction

The user's answers so far, as the starting point for design. The phase that designs each item confirms or revises it with the user; none is a final specification.

- **Optional:** Break can be guided or plain. Focus does not change.
- **Explicit start:** a guided Break, like a plain one, starts only on the user's action.
- **Routines:** several from the first version, each with a name.
- **Step names:** written by the user; the user marked this as important.
- **Step capabilities:** all four below are wanted in the first version. The table describes what users can express, not the editor layout or data model.
- **Advance:** every step is timed and the next one starts by itself. The user can pause, skip, and go back.
- **Length:** Break keeps its fixed duration. Spare time after the routine is rest. A routine longer than the Break cannot be started.
- **Guidance:** on screen with the screen kept awake, sounds and vibration, spoken instructions, and guidance while the phone is locked or another app is open. All four are wanted. Their controls, cue behavior, and technical approach are left for design; locked/background guidance also needs feasibility evidence.
- **Device:** no iPhone for testing now, maybe later, so on-screen work comes first.
- **Order:** Guided Break comes before the other Stage 2 proposals, which become Stage 3.

| Capability | Information to support | Base length, excluding timed gaps | Example |
| --- | --- | --- | --- |
| Total time | Name, time | The time | "Relax", 30 s: 30 s |
| Repetitions with a hold | Name, count, hold, optional pause between repetitions | Count × hold | "Stretch your neck", 10 × 5 s: 50 s without pauses |
| Repetitions with no hold | Name, count, time per repetition or a default | Count × time per repetition | "Move your shoulders up", 10 × 3 s (3 s is only an illustration): 30 s |
| Both sides | Any suitable step, entered once, run left then right | Twice the step | "Move your hand down", 10 × 5 s on each side: 100 s |

If the shoulder repetitions take 3 seconds each, the four example steps take 2 min 40 s without pauses, using only the left hand as requested. That leaves 12 min 20 s of rest in a 15-minute Break. This illustrates the fixed Break length; 3 seconds is not an agreed default, and repeating a routine to fill more time is still a design question.

### Design still to do

The [design topics by phase](roadmap.md#design-topics-by-phase) cover selection and Settings, step fields and timing, editing, skip/back, recovery, cues, and locked/background behavior. **User direction** above is where design starts; every other topic is open unless the current invariants govern it. Earlier agent suggestions are options to consider, not approved requirements.

In particular, the roadmap does not yet choose how combined timing fields work, whether both sides is a step kind or an option, how rounds work, what Skip and Back do to the remaining time, or whether edits affect a running routine. It also does not select APIs for sounds, speech, or locked/background guidance.

### Boundaries for the design

Preserve one active phase, explicit Break confirmation on every cycle, `TimerStore` as the only state owner, wall-clock deadlines, local-only data, and correctness without continuous background execution. A guided routine belongs to the active Break, with one authoritative Break deadline; it does not start an independent timer or, under the current direction, extend the fixed Break duration.

Design how to save enough information to recover an active routine, including the effects of Skip and Back, and how invalid routine data is handled without breaking the timer. Keep the existing accessibility standard and usability when alerts are denied. These need acceptance checks in the relevant phase specs, not a new implementation model in this mission.

On-screen guidance comes first because no test iPhone is available. Locked/background guidance remains a requested outcome, not a delivery guarantee: its phase must establish what is supported and verify it on a real device. Any limitation or proposed reduction in scope comes back to the user.

## Still to build

Guided Break, described above; the other roadmap phases; local release documentation; a TODO to clear the contrast allowance in the accessibility audit ([I28](phases/I28-accessibility-audit.md)). The allowance covers the header subtitle and also any contrast issue the audit reports without naming an element, so a passing audit does not prove the subtitle is the only one. See the [roadmap](roadmap.md).

## Invariants

- At most one phase is active. An unpaused running phase has a deadline and no saved paused duration; a paused phase has positive remaining time and no deadline. Idle, waiting, and completed have neither.
- A delayed launch or callback performs only the applicable transition; it does not skip the user's Break confirmation or replay missed ticks. Break requires explicit confirmation on every cycle.
- Repeated or stale actions cannot start extra phases or change a later cycle.
- A launch restores a running or paused phase. A phase that expired while the app was closed shows its end screen once. A state already waiting or completed when the app closed resets to idle at launch, keeping the saved durations. Returning from the background is not a launch and keeps every state.
- Pause at or after expiry completes the phase rather than adding time. Deadlines remain wall-clock.
- Invalid stored durations cannot bypass the agreed bounds. One-minute defaults and whole-minute ranges stay unless explicitly revised.
- Denied alerts do not block in-app completion or actions. Correctness does not depend on continuous background execution.
