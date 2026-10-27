# iOS mission

Status: accepted direction on 2026-10-16; baseline reviewed against `6e00429`. Future requirements below are planned, not implemented.

## Purpose and boundaries

Deliver a small, reliable offline iPhone timer for Focus followed by an explicitly confirmed Break. Maintain correct remaining time across suspension and relaunch using persisted deadlines and local notifications. The app must remain usable when notifications are denied; sound and delivery timing are subject to system settings.

Retain native SwiftUI, iPhone-only portrait presentation, and iOS 26 minimum. No accounts, analytics, cloud sync, network backend, shared cross-platform code, or Chrome changes. App Store delivery is a later possibility, not a committed release target. Custom sound remains optional and outside the planned baseline.

## Implemented baseline

- Configurable Focus and Break; defaults are one minute each. UI uses whole-minute steps: Focus 1–240 minutes, Break 1–120 minutes. Since [I07](phases/I07-enforce-invariants.md), the store rounds saved and started durations to whole minutes and clamps them to the same ranges, which the UI reads from shared constants. On launch, saved timer state that breaks the invariants below is repaired, and the status line says so.
- Flow: `idle → runningA → waitingForAConfirm → runningB → completed`. Pause is a flag on either running phase. Break never starts automatically after Focus. Since [I13](phases/I13-completed-state.md), a finished Break enters a saved `completed` phase that keeps the cycle ID and survives relaunch; until Done (I14) and Restart (I15) exist, Start Focus begins a new cycle from completed and Cancel returns to idle, and durations can be edited while completed.
- Start, Start Break, pause/resume, and cancel/reset; duration controls are enabled only in idle and, since [I13](phases/I13-completed-state.md), in completed; they are disabled while a phase runs, is paused, or waits for Break confirmation. Cancel retains saved configuration.
- Codable configuration and runtime state in UserDefaults; running phases use absolute Date deadlines and paused phases use remaining seconds. Configuration edits persist when Focus starts. Since [I08](phases/I08-schema-versioning.md), saved data carries a schema version, and records saved before versioning are migrated at launch with their settings and timer state kept. Since [I09](phases/I09-recover-saved-records.md), a record that cannot be read is replaced with defaults (config) or idle (state) with the same notice, the other record is kept, and an unsupported saved version is replaced on the first save.
- Foreground countdown updates once per second; launch and foreground activation reconcile expired deadlines. Since [I12](phases/I12-expiry-clock-edges.md), pausing at or after expiry completes the phase instead of pausing; after a backward clock jump a running deadline more than the phase's length away is moved to now + that length (no notice); and a saved paused time longer than the phase is clamped at launch with the correction notice. A forward jump completes the phase on the next reconcile and never skips Break confirmation.
- Local completion notifications with default sound; Focus notification “OK” opens the app and requests Break. Pending requests are removed on pause/cancel. Since [I10](phases/I10-cycle-identity.md), each Focus → Break cycle has a saved cycle ID that completion notifications carry, and OK starts Break only when its ID matches the current cycle; an OK from an earlier cycle, without an ID, or repeated after Break started changes nothing. Since [I11](phases/I11-clean-up-alerts.md), delivered alerts are removed once they no longer match the timer: starting Break removes the Focus alert, Cancel and a new Focus remove all, and launch or activation keeps the Focus alert only while waiting for Break and the Break alert only while Break runs or, since I13, while completed.
- Warm card-based UI, native symbols and accessibility labels for pause/cancel. Final app icon artwork is missing. Since [I24](phases/I24-end-states.md), the status card has a distinct presentation at each end: Focus end (waiting for Break confirmation) is amber with a cup symbol, "Focus complete", and a Start Break button; Break end is green with a checkmark, "Cycle complete", and a Start Focus button. Since I13 the Break end is the saved completed state (I24 used a transient flag until then).

The archived status reports a simulator build, installation, launch, and initial-screen screenshot check. Full flow, lifecycle, and notifications are not recorded as manually verified. No new runtime verification is claimed by this migration.

## Required direction

1. Verify the existing behavior before extending it, and add deterministic tests using injectable time, storage, and notification boundaries.
2. Validate persisted invariants, introduce schema migration, and recover invalid state safely while preserving valid configuration.
3. Make transitions and notification actions safe under duplicates and stale cycles. Cancel and transitions must invalidate obsolete pending and delivered notifications.
4. Introduce a durable `completed` state. After Break, offer Done (idle) and Restart (new Focus using saved durations), both in-app and through notifications. Break must still require explicit confirmation on each cycle.
5. Provide notification-permission guidance, then check accessibility and produce final icon artwork and local release documentation.

## Behavioral invariants and acceptance

- At most one phase is active. An unpaused running phase has a deadline and no saved paused duration; a paused phase has positive remaining time and no deadline. Idle, waiting, and completed states have neither.
- A delayed launch or callback performs only the applicable transition; it does not skip the user's Break confirmation or replay missed ticks.
- Repeated/stale actions cannot start extra phases or change a later cycle. Done and Restart remain available after relaunch in completed state.
- Pause at or after expiry reconciles completion rather than adding time. Define and test wall-clock jump behavior while retaining wall-clock deadlines as the baseline.
- Keep one-minute defaults and whole-minute UI ranges unless explicitly revised. Invalid stored durations cannot bypass the agreed bounds.
- Denied alerts do not block in-app completion or actions. Do not depend on continuous background execution for correctness.

## References

[Stack](tech-stack.md), [small-phase roadmap](roadmap.md), [archived iPhone status](../history/focustimer_ios_spec.md), [original product/technical specification](../history/FOCUSTIMER_SPEC.md). The original prompt establishes the Done/Restart intent; it does not prove implementation.
