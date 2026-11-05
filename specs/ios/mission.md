# iOS mission

## Purpose and boundaries

A small, reliable offline iPhone timer for Focus followed by an explicitly confirmed Break. Remaining time stays correct across suspension and relaunch using persisted deadlines and local notifications. The app stays usable when notifications are denied; sound and delivery timing are subject to system settings.

Native SwiftUI, iPhone-only portrait, iOS 26 minimum. No accounts, analytics, cloud sync, network backend, shared cross-platform code, or Chrome changes. App Store delivery is a later possibility, not a committed target.

## Current behavior

- **Durations:** defaults are one minute each. Whole-minute steps: Focus 1–240 minutes, Break 1–120 minutes. Saved and started durations are rounded and clamped to the same ranges. They can be edited only in idle and completed, and persist when Focus starts or on Done.
- **Flow:** `idle → runningA → waitingForAConfirm → runningB → completed`. Pause is a flag on either running phase. Break never starts automatically. From completed, Done returns to idle and Start Focus begins a new cycle (until Restart exists); repeating Done changes nothing. Cancel (×) returns to idle from every other phase and keeps the configuration; it is not offered in completed.
- **Saved data:** configuration and timer state are saved locally with a schema version. Running phases save absolute deadlines; paused phases save remaining seconds. Older versions migrate at launch and keep their data. Invalid saved state is repaired with a correction notice. An unreadable record is replaced with defaults or idle, with the same notice, and the other record is kept. A newer or unreadable version loads defaults and is replaced on the first save.
- **Time:** the countdown updates once per second in the foreground. Launch and activation reconcile expired deadlines. Pausing at or after expiry completes the phase. After a backward clock jump, a deadline more than the phase's length away moves to now + that length, with no notice. A forward jump completes the phase on the next reconcile and never skips Break confirmation. A saved paused time longer than the phase is clamped at launch with the notice.
- **Notifications:** completion alerts use the default sound. Each Focus → Break cycle has a saved cycle ID that alerts carry. The Focus alert's OK opens the app and starts Break only for the matching cycle; a stale, missing, or repeated action changes nothing. Pending requests are removed on pause and cancel. Delivered alerts are removed once they no longer match the timer: starting Break removes the Focus alert, and Cancel, Done, or a new Focus removes all. Launch and activation keep the Focus alert only while waiting for Break, and the Break alert only while Break runs or the cycle is completed.
- **UI:** warm card-based design with native symbols and accessibility labels for pause and cancel. Focus end is amber with a cup, "Focus complete", and Start Break. Break end is green with a checkmark, "Cycle complete", Start Focus, and Done. The final app icon is missing.

Not yet verified: behavior on a physical device, and the deferred suspension checks from [I02](phases/I02-exercise-lifecycle-notifications.md).

## Still to build

In-app Restart (new Focus using saved durations) after Break; Done and Restart through notifications; notification-permission guidance; accessibility checks; final icon; local release documentation. See the [roadmap](roadmap.md).

## Invariants

- At most one phase is active. An unpaused running phase has a deadline and no saved paused duration; a paused phase has positive remaining time and no deadline. Idle, waiting, and completed have neither.
- A delayed launch or callback performs only the applicable transition; it does not skip the user's Break confirmation or replay missed ticks. Break requires explicit confirmation on every cycle.
- Repeated or stale actions cannot start extra phases or change a later cycle. Done and Restart remain available after relaunch in completed.
- Pause at or after expiry completes the phase rather than adding time. Deadlines remain wall-clock.
- Invalid stored durations cannot bypass the agreed bounds. One-minute defaults and whole-minute ranges stay unless explicitly revised.
- Denied alerts do not block in-app completion or actions. Correctness does not depend on continuous background execution.
