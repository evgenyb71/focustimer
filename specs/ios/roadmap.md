# iOS roadmap

## Next phases

Work from the top. The user can reorder or split phases; note why in the phase spec.

| Phase | Deliverable | Exit check |
| --- | --- | --- |
| I14 | Add in-app Done | Completed → idle; configuration survives; repeated Done is harmless |
| I15 | Add in-app Restart | Completed → new Focus with saved durations and new cycle identity; Break still needs confirmation |
| I16 | Add notification Done | Valid Break completion notification routes to Done; stale/duplicate actions are ignored |
| I17 | Add notification Restart | Valid action starts one Focus; foreground/background/relaunch paths are checked |
| I18 | Show permission status and useful failure guidance | Denied alerts and scheduling errors do not block timer flow; Settings guidance is available |
| I22 | Decide and implement launch-state policy | Record in the [mission](mission.md) whether each state (running, paused, waiting for Break confirmation, completed) is restored or reset on relaunch, keeping deadline recovery for running phases unless the decision changes that invariant. Behavior matches the decision for every state, with tests and a manual relaunch check; I01 observed the app reopening in waiting-for-Break. Note: when timer is On, exit and re-start before timer ends - gets us back to phase + correct time to end |
| I23 | Make the active timer obvious | Design note in the phase spec, then the SwiftUI change: Focus and Break are visually distinct in running, paused, and waiting states. User-reported simulator screenshots show the active timer is identifiable at a glance; accessibility labels name it |
| I20 | Supply final app icon | Complete the 1024×1024 artwork slot and verify appearance in the app/launcher |
| I19 | Verify accessibility and visual resilience (after the UI phases above) | Check VoiceOver, Dynamic Type, contrast, focus/order, control labels and largest supported text sizes |
| I21 | Prepare local release notes and verification checklist (last) | Record version/build, privacy behavior, known limits, device checks, and reproducible build steps; write the changelog from Git history since 2026-11-02 |

Later decisions, not scheduled: App Store submission, store screenshots and privacy forms, signing and distribution automation, and release policy. Not part of this roadmap: custom sound, alternative defaults, fractional-minute input, broader device or OS support, sync, and analytics.

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
