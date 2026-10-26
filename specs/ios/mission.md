# iOS mission

Status: accepted direction on 2026-10-16; baseline reviewed against `6e00429`. Future requirements below are planned, not implemented.

## Purpose and boundaries

Deliver a small, reliable offline iPhone timer for Focus followed by an explicitly confirmed Break. Maintain correct remaining time across suspension and relaunch using persisted deadlines and local notifications. The app must remain usable when notifications are denied; sound and delivery timing are subject to system settings.

Retain native SwiftUI, iPhone-only portrait presentation, and iOS 26 minimum. No accounts, analytics, cloud sync, network backend, shared cross-platform code, or Chrome changes. App Store delivery is a later possibility, not a committed release target. Custom sound remains optional and outside the planned baseline.

## Implemented baseline

- Configurable Focus and Break; defaults are one minute each. UI uses whole-minute steps: Focus 1–240 minutes, Break 1–120 minutes. Since [I07](phases/I07-enforce-invariants.md), the store rounds saved and started durations to whole minutes and clamps them to the same ranges, which the UI reads from shared constants. On launch, saved timer state that breaks the invariants below is repaired, and the status line says so.
- Flow: `idle → runningA → waitingForAConfirm → runningB → idle`. Pause is a flag on either running phase. Break never starts automatically after Focus.
- Start, Start Break, pause/resume, and cancel/reset; duration controls are disabled outside idle. Cancel retains saved configuration.
- Codable configuration and runtime state in UserDefaults; running phases use absolute Date deadlines and paused phases use remaining seconds. Configuration edits persist when Focus starts. Since [I08](phases/I08-schema-versioning.md), saved data carries a schema version, and records saved before versioning are migrated at launch with their settings and timer state kept. Since [I09](phases/I09-recover-saved-records.md), a record that cannot be read is replaced with defaults (config) or idle (state) with the same notice, the other record is kept, and an unsupported saved version is replaced on the first save.
- Foreground countdown updates once per second; launch and foreground activation reconcile expired deadlines.
- Local completion notifications with default sound; Focus notification “OK” opens the app and requests Break. Pending requests are removed on pause/cancel. Since [I10](phases/I10-cycle-identity.md), each Focus → Break cycle has a saved cycle ID that completion notifications carry, and OK starts Break only when its ID matches the current cycle; an OK from an earlier cycle, without an ID, or repeated after Break started changes nothing.
- Warm card-based UI, native symbols and accessibility labels for pause/cancel. Final app icon artwork is missing.

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
