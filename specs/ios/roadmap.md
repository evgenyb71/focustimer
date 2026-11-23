# iOS roadmap

## Next phases

Work from the top. The user can reorder or split phases; note why in the phase spec.

IDs are not renumbered, so the order is the table order, not the ID order. This is a planning outline, not a set of approved phase specs. When the user starts a phase, agree only the decisions it needs, write its acceptance checks, and split it if it is too large to review. The current behavior and invariants in the [mission](mission.md) stay in force until a verified phase changes them.

### Stage 2: Guided Break

Focus stays a plain timer. Break can optionally guide the user through a routine of their own steps. The [mission](mission.md#planned-guided-break-not-built) is the source of intent and user direction, which design can revise with the user: several named routines, user-written step names, timed progression, pause/skip/back, a fixed Break duration with spare time as rest, and all four requested forms of guidance.

I36 establishes the overall experience. Each later phase includes design for its own area before implementation; I36 does not need to settle every field, control, cue, or storage detail. No phase is started by this roadmap update.

| Phase | Focus | Evidence needed to finish (to refine when starting) |
| --- | --- | --- |
| I36 | Product and interaction design (docs only, with a phase spec to hold its decisions) | User-agreed flow for creating/selecting a routine and choosing plain or guided Break, with rough screens and the main failure paths. Identify dependencies and feasibility questions; revise the later phases without deciding their internals. |
| I37 | Routine and step model, timing rules, and local storage | Agreed step examples can be represented, validated, and timed, including both sides. Tests cover duration calculations, invalid data, migration, and recovery; existing timer data survives an upgrade. |
| I38 | Routine management and editing | A user can manage several routines and create, name, order, edit, and remove their steps. The agreed timing and validation rules are understandable; data survives relaunch; VoiceOver and largest-text checks cover the new screens. |
| I39 | Guided Break execution and recovery | The agreed progression, pause, skip, back, and rest behavior works within one Break. Tests cover boundaries, relaunch, clock changes, and damaged saved state; manual lifecycle checks are recorded. Focus and plain Break still work. |
| I40 | Routine selection and on-screen guidance | A user-reported simulator cycle covers choosing a routine, explicit Break start, following the steps with the screen awake, controls, rest, and completion. Overlong or unavailable routines follow the agreed path; accessibility and notification-entry paths are checked. |
| I41 | Sound and vibration guidance while the app is open | Agreed cues and controls work with progression and user actions, without obsolete cues after a state change. Timing remains correct without cues. Sound checks are recorded; physical vibration stays unverified until a real iPhone check. |
| I42 | Spoken guidance while the app is open | Agreed spoken content and controls work during a routine and respond correctly to pause, navigation, and cancellation. VoiceOver, interruptions, and other audio are checked as agreed, with device-dependent limits recorded. |
| I43 | Locked/background guidance feasibility (experiment, no production integration) | Current Apple documentation and real-device experiments establish which requested guidance can work while locked or in another app. Record limits, effects on the existing timer/alerts, and a user go/no-go decision for I44. |
| I44 | Locked/background guidance, conditional on I43 | Implement only the supported, user-agreed approach. Real-device checks cover a full routine, interruptions, return to the app, state changes, and obsolete-cue cleanup. Record any gap from the mission explicitly. |

#### Order

The proposed sequence is model → editor → execution → on-screen use → foreground cues → locked/background guidance. I36 checks this sequence; later design can send a decision back to an earlier phase before code depends on it. Split broad rows into smaller phases when their scope is known, preserving existing IDs and recording dependencies.

Guided Break takes priority over the earlier proposals, retained as Stage 3 below. Simulator-verifiable work comes first. I43's feasibility questions should be identified in I36, but hardware evidence and I44 wait for a test iPhone. Do not choose a background mechanism or promise delivery in the meantime.

#### Design topics by phase

These are questions to resolve with the user when needed, not decisions made now. If a choice affects an earlier dependency, agree it before implementing that dependency.

- **I36 — Overall experience:** where Settings and routine management live; how the user selects plain/guided Break and a routine; what the Focus alert's OK should do; what happens when no usable routine fits. Confirm scope around sample content, an exercise library, media, and sharing rather than treating earlier suggestions as approved features or exclusions.
- **I37 — Step language and timing:** a name alone or additional instructions; the supported combinations of total time, count, hold, and repetition duration; defaults, units, bounds, rounding, and conflicting values. Decide how both sides, between-repetition/side pauses, preparation time, and any rounds affect the total. Both sides as an option and total/count-derived repetition time are candidates, not chosen representations. Follow the repository's schema-version and migration policy for saved-format changes.
- **I38 — Editing experience:** create/edit/save/cancel behavior, ordering, removal, empty states or starting examples, and feedback about total routine time versus Break time. Settle any remaining model choices before storing them.
- **I39 — Execution rules:** the exact meaning of pause, skip, and back within the fixed Break length, especially with no spare time; edits or deletion during a run; rest and completion; saved recovery after navigation, suspension, relaunch, or clock changes. Candidates include a per-run routine copy, skipped time becoming final rest, and Back restarting a step; compare them rather than assume them. Decide treatment of missed steps and cues without replaying missed timer ticks. Design how Debug short minutes apply consistently to Break and its steps.
- **I40 — Guidance screen and entry paths:** current/next step information, side/repetition/time displays, control placement, rest/completion presentation, and when the screen stays awake. Integrate the I36 selection and alert-entry decisions, including a changed or unavailable routine; preserve explicit confirmation and stale-action protection.
- **I41 — Nonverbal cues:** which events need sound or vibration, their controls, system-setting and permission behavior, and how cues are invalidated on pause, skip, back, Cancel, or completion. Custom sounds remain outside this roadmap unless the user reopens that boundary.
- **I42 — Speech:** what text is spoken and when, repetition verbosity, controls, language, overlap, VoiceOver coexistence, interruptions, and interaction with other audio. Agree whether missed instructions are skipped or summarized without changing timer correctness.
- **I43–I44 — Away from the app:** which cues are required under lock or in another app, acceptable delays and fallbacks, permissions, supported platform mechanisms, and real-device test scenarios. Research notification scheduling, supported audio behavior, and any relationship to Stage 3's Live Activity/AlarmKit work; do not assume those mechanisms are interchangeable or solve step guidance. If the evidence requires a Stage 3 prerequisite, revise the order explicitly.

#### Supporting quality work and device checks

These retained phases support Stage 2 without becoming prerequisites for its initial design. Agree their placement when starting the affected work.

| Phase | Scope | Evidence needed |
| --- | --- | --- |
| I30 | Resolve the contrast-audit allowance left by [I28](phases/I28-accessibility-audit.md) | Investigate the subtitle and no-element findings and aim to remove both allowances. Any exception that remains is explained and user-agreed; it is not recorded as a clean audit. Keep new screens covered as they are added. |
| I29 | Real-iPhone verification, when a device is available | Recheck deferred suspension cases from [I02](phases/I02-exercise-lifecycle-notifications.md) against today's mission, alert actions and background launches, clock changes, VoiceOver, and Release behavior. Include Guided Break behavior built by then; each result is user-reported or explicitly unverified. Defects become scoped follow-up work. |

The user has no test iPhone now. I29 and hardware-dependent checks in I41–I44 remain pending; simulator results cannot close them. If the device remains unavailable or I43 is a no-go, ask the user whether to defer that work or revise Stage 2's scope. Foreground progress is not evidence that locked/background guidance is complete.

#### Stage 2 review

Before moving on, review the implemented experience against the mission: plain and guided Break, all agreed step capabilities, fixed-length execution, editing, recovery, accessibility, and each requested guidance mode. Record verified behavior and remaining limits in the phase specs and update the mission/tech stack to match. The user decides whether any device-blocked or infeasible work can be deferred; do not silently move it to Stage 3 or call it delivered.

### Stage 3: Locked iPhone and everyday use

Deliverables, exit checks, and order are drafts, agreed when each phase starts.

| Phase | Deliverable | Exit check |
| --- | --- | --- |
| I31 | Quicker duration entry, with a decision on the defaults | Setting 25 and 5 minutes from a first launch takes far fewer than today's 28 one-minute steps, also with VoiceOver and the largest text; ranges and whole minutes hold; an upgrade keeps saved durations |
| I32 | Duration presets | A preset sets both durations, only in idle and completed. If users can save their own, they survive relaunch, with the next `schemaVersion` and a migration test |
| I33 | Live Activity that shows the countdown on the Lock Screen and Dynamic Island, without buttons | On a real iPhone it matches the app while running, paused, at both ends, and after Cancel, Done, and relaunch; it is never wrong after a phase ends while the app is suspended; with Live Activities off, the timer is unchanged |
| I34 | Live Activity buttons: Pause, Resume, Start Break, Restart, Done | Each acts as the in-app button, only for the matching cycle; a stale or repeated tap changes nothing; Break starts only on an explicit tap |
| I35 | AlarmKit experiment, with no production code | The AlarmKit questions in the notes below are answered on a real iPhone, and the user records go or no-go |
| I21 | Prepare local release notes and verification checklist (last) | Record version/build, privacy behavior, known limits, device checks, and reproducible build steps; write the changelog from Git history since 2026-11-02 |

### Other open decisions

- **Test iPhone:** I29, I33, I34, I35, I43, I44, and the vibration check in I41 need one on iOS 26 or later. The user may have one later; availability is checked when one of these starts.
- **Own use or App Store:** asked at the Stage 2 review. It decides whether the release items below are scheduled, and whether I21 moves ahead of the features.
- **Defaults:** decided in I31, which may replace one minute each with 25 and 5. One minute stays an invariant until the user revises it.

### Notes for I33 to I35

Research questions carried forward from the draft of 2026-11-23. The links are leads, not verified findings or architecture decisions. Recheck current Apple documentation for the target OS and SDK, then record real-device evidence in the relevant phase before choosing an approach. I43 can use the same research where it overlaps, without treating a candidate API as a prerequisite.

- **State ownership:** how can an activity display timer state and route actions through the existing cycle-checked methods while keeping `TimerStore` authoritative?
- **Phase expiry while suspended:** without a push server, what can the activity reliably show when a phase expires and the app cannot update it? Investigate [`staleDate`](https://developer.apple.com/documentation/activitykit/activitycontent/staledate), including this [developer report](https://developer.apple.com/forums/thread/740406), and test the fallback display before committing to the feature.
- **Background Restart:** can the Break alert's Restart start an activity without opening the app, reuse an existing one, or require another user action? What happens if the activity is unavailable?
- **Lifetime:** what are the current activity lifetime and dismissal limits, and how should a long timer pause be represented when they are reached? This [lifetime discussion](https://developer.apple.com/forums/thread/797676) is a starting point to verify.
- **Process and data:** which process runs each button intent, and what access to saved state does it need? Decide whether any data-sharing change is necessary only after establishing this.
- **AlarmKit:** can a fixed-date alarm provide the required completion behavior while leaving the timer authoritative? Start with [Apple's AlarmKit session](https://developer.apple.com/videos/play/wwdc2025/230/). Verify silent-mode and Focus behavior, Pause/Cancel cleanup, authorization, signing and entitlement requirements (including this [developer report](https://developer.apple.com/forums/thread/797950)), and compatibility with existing alert actions before a go/no-go decision.

### Later candidates

Not scheduled and without IDs. Promote one to a phase when the user chooses it.

- **Timer**
  - Local history: completed cycles and daily totals. Needs the next `schemaVersion`, stays on the device, and is not analytics.
  - Add time to a running phase. The deadline cap would undo it unless each run saves its own length.
  - A longer Break after several cycles, still confirmed each time.
  - Keep the screen awake during Focus or a plain Break; confirm or undo an accidental Cancel; a haptic or in-app sound when alerts are denied; hours in the time display above 60 minutes.
- **System:** Shortcuts, Siri, and Action button through App Intents, reusing the I34 actions; a Control Center control; a Home Screen widget; AlarmKit alerts if I35 is a go.
- **Guidance and polish:** an Open Settings button and a later permission prompt (I18); animations between states (I23); a layered Icon Composer icon (I20).
- **Quality:** UI tests of the full flow, now that the target exists (I28); Switch Control and Voice Control; a colour-blind check; localization, since the spoken durations are built in English.
- **Chores:** align the test targets' `com.boch` bundle IDs with the app's.
- **Release, if the App Store is the target:** a privacy manifest covering UserDefaults (confirm against Apple's current rules), App Store submission, store screenshots and privacy forms, signing and distribution automation, and release policy.

Not part of this roadmap: custom sound, fractional-minute input, broader device or OS support, sync, and analytics. Alternative defaults left this list on 2026-11-23 and are decided in I31.

## Completed

Each spec holds the evidence and limitations. The app before I01 is in Git history and [the archived status](../history/focustimer_ios_spec.md).

| Phase | Result | Spec |
| --- | --- | --- |
| I01 | Recorded the build and manual Focus → Break flow | [I01](phases/I01-record-baseline-flow.md) |
| I02 | Exercised pause, cancel, and relaunch; suspension and notification rows deferred | [I02](phases/I02-exercise-lifecycle-notifications.md) |
| I03-I04 | Injected clock and key-value store | [I03-I04](phases/I03-I04-inject-clock-and-store.md) |
| I05 | Notification boundary and unit-test target | [I05](phases/I05-notification-boundary-tests.md) |
| I06 | Baseline transition tests | [I06](phases/I06-baseline-transition-tests.md) |
| I07 | Enforced duration bounds and repaired invalid saved state | [I07](phases/I07-enforce-invariants.md) |
| I08 | Schema versioning and migration | [I08](phases/I08-schema-versioning.md) |
| I09 | Recovery from unreadable saved records | [I09](phases/I09-recover-saved-records.md) |
| I10 | Cycle identity for notification actions | [I10](phases/I10-cycle-identity.md) |
| I11 | Removal of obsolete delivered alerts; fixed the notification OK crash | [I11](phases/I11-clean-up-alerts.md) |
| I12 | Expiry and clock-jump edge cases | [I12](phases/I12-expiry-clock-edges.md) |
| I13 | Saved completed state | [I13](phases/I13-completed-state.md) |
| I24 | Distinct Focus-end and Break-end presentation | [I24](phases/I24-end-states.md) |
| I25 | Unit tests split into one file per suite | [I25](phases/I25-split-unit-tests.md) |
| I14 | In-app Done from completed, which saves the durations; × hidden there | [I14](phases/I14-in-app-done.md) |
| I15 | In-app Restart, and the launch-state policy (absorbed I22): working states restored, finished states reset | [I15](phases/I15-in-app-restart.md) |
| I16 | Done on the Break alert, without opening the app; both alerts reworded | [I16](phases/I16-notification-done.md) |
| I26 | Debug-only short minutes for manual checks, set with `scripts/debug-minute.sh`; Release unaffected | [I26](phases/I26-debug-short-durations.md) |
| I17 | Restart on the Break alert, without opening the app; starts one Focus, ignored after a reset | [I17](phases/I17-notification-restart.md) |
| I18 | Hint while alerts are denied, pointing to Settings; notice when an alert cannot be scheduled; timer flow unaffected | [I18](phases/I18-permission-guidance.md) |
| I23 | Teal Focus and sage Break on the status card and duration row while running or paused; VoiceOver names the timer | [I23](phases/I23-active-timer.md) |
| I20 | App icon of two timer rings, teal Focus behind sage Break, in light, dark, and tinted versions, drawn by `scripts/make-app-icon.swift` | [I20](phases/I20-app-icon.md) |
| I19 | Light and dark themes from one contrast-tested palette; layout adapts to the largest text sizes; clearer VoiceOver labels; Inspector and VoiceOver check deferred to I28 | [I19](phases/I19-accessibility.md) |
| I27 | Alerts that arrive while the app is open play only the sound, with no banner or Notification Center entry; background alerts unchanged | [I27](phases/I27-quiet-foreground-alerts.md) |
| I28 | Accessibility audit as UI tests in their own scheme, with four contrast fixes; one subtitle allowance left as a TODO; VoiceOver walk user-reported | [I28](phases/I28-accessibility-audit.md) |
