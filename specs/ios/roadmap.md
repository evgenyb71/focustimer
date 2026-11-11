# iOS roadmap

## Next phases

Work from the top. The user can reorder or split phases; note why in the phase spec.

| Phase | Deliverable | Exit check |
| --- | --- | --- |
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
| I14 | In-app Done from completed, which saves the durations; × hidden there | [I14](phases/I14-in-app-done.md) |
| I15 | In-app Restart, and the launch-state policy (absorbed I22): working states restored, finished states reset | [I15](phases/I15-in-app-restart.md) |
| I16 | Done on the Break alert, without opening the app; both alerts reworded | [I16](phases/I16-notification-done.md) |
| I26 | Debug-only short minutes for manual checks, set with `scripts/debug-minute.sh`; Release unaffected | [I26](phases/I26-debug-short-durations.md) |
| I17 | Restart on the Break alert, without opening the app; starts one Focus, ignored after a reset | [I17](phases/I17-notification-restart.md) |
| I18 | Hint while alerts are denied, pointing to Settings; notice when an alert cannot be scheduled; timer flow unaffected | [I18](phases/I18-permission-guidance.md) |
