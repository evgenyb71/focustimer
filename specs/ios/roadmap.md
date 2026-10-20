# iOS roadmap

Status: accepted high-level order on 2026-10-16. Baseline `6e00429`. Completed phases are listed in the table below; the others are unstarted; documentation approval does not mark implementation complete.

## Retrospective

| Phase | Delivered in source | Evidence |
| --- | --- | --- |
| I-R01 | Initial two-phase SwiftUI app | `8df23b5`, 2025-12-25 |
| I-R02 | Xcode scaffolding, Codable fix, workspace tracking | `d69c7e2`, `1a41f59`, 2025-12-26 |
| I-R03 | Replacement iPhone-only Swift 6 / iOS 26 project | `f646069`, 2026-07-10 |
| I-R04 | Focus/confirmation/Break, pause/resume/cancel, persisted deadlines, local notifications and UI | `TimerStore.swift`, `NotificationScheduler.swift`, `ContentView.swift` in I-R03 |
| I-R05 | Automatic-signing development team configured | `6e00429`, 2026-10-15 |

The archived status reports simulator build/install/launch and initial-screen inspection for I-R03. Full flow, lifecycle, and notification QA remain unverified. These rows describe implemented capabilities, not completion of the future acceptance checks.

## Completed phases

Move a phase here when its phase spec is marked verified and the work is pushed. Link the phase spec for evidence and limitations.

| Phase | Deliverable | Verified | Phase spec | Pushed |
| --- | --- | --- | --- | --- |
| I01 | Recorded build and manual Focus → confirmation → Break flow (user-reported, iPhone 18 Pro Max simulator, iOS 27, Xcode 27.0) | 2026-10-19 | [I01-record-baseline-flow](phases/I01-record-baseline-flow.md) | `ce8fa8b` on `main` |
| I02 | Pause/resume, cancel, relaunch exercised; matrix recorded, no defects found. Deferred, unverified: R3, R5, S1-S3, N1-N8 (suspension, notifications) | 2026-10-19 | [I02-exercise-lifecycle-notifications](phases/I02-exercise-lifecycle-notifications.md) | `2b25b16` on `main` |
| I03-I04 | Injected `Clock` and one `KeyValueStore` into `TimerStore` (internal initializer; production uses `SystemClock` and `UserDefaults.standard`); saved state survives the update; flow unchanged (agent-run, iPhone 17 Pro simulator, iOS 26.5). Test control shown by design only until I05/I06 | 2026-10-20 | [I03-I04-inject-clock-and-store](phases/I03-I04-inject-clock-and-store.md) | `cb2b3aa` on `main` |
| I05 | `NotificationScheduling` boundary injected into `TimerStore` (interval from the injected clock); `FocusTimerTests` Swift Testing target with 6 passing tests and a documented `xcodebuild test` command (agent-run iPhone 17 Pro iOS 26.5; user-reported Cmd+U) | 2026-10-20 | [I05-notification-boundary-tests](phases/I05-notification-boundary-tests.md) | `131616d` on `main` |
| I06 | Deterministic `TimerStore` tests: Focus/Break, explicit confirmation, pause/resume, cancel, delayed reconciliation, relaunch from store, notification OK path, countdown display (36 tests; agent-run iPhone 17 Pro iOS 26.5, user-reported Cmd+U). Known issue: pause at expiry adds time (I12) | 2026-10-20 | [I06-baseline-transition-tests](phases/I06-baseline-transition-tests.md) | `75c92c1` on `main` |

## Small forward phases

Execute one phase at a time, in order. Before code, write a short phase spec at `specs/ios/phases/Ixx-short-name.md` covering intended behavior, non-goals, affected components, and concrete acceptance checks. Update it with evidence and limitations after verification. Split a phase further if it cannot fit a focused, reviewable change; do not bundle later features into a refactor.

| Phase | Small deliverable | Exit check |
| --- | --- | --- |
| I07 | Align and enforce configuration/state invariants | Test invalid ranges, missing deadlines, impossible paused states; retain agreed minute rules |
| I08 | Add schema versioning and migration of current records | Fixtures from existing unversioned keys retain valid settings and timer state |
| I09 | Recover corrupt/partial/unsupported saved records | Safe idle fallback, preserve valid config; relaunch remains usable |
| I10 | Persist a cycle identity and validate action provenance | An old Focus notification cannot start Break in a newer cycle; duplicate actions are harmless |
| I11 | Clean up obsolete pending and delivered notifications | Cancel, phase change, and new cycle invalidate old alerts; current valid alert remains actionable |
| I12 | Settle expiry and clock-edge behavior | Pause at expiry completes; test duplicate callbacks, delayed activation, forward/backward clock changes |
| I13 | Add and persist the completed state | Break expiry enters completed once; migration/relaunch restores it with no active deadline |
| I14 | Add in-app Done | Completed → idle; configuration survives; repeated Done is harmless |
| I15 | Add in-app Restart | Completed → new Focus with saved durations and new cycle identity; Break still needs confirmation |
| I16 | Add notification Done | Valid Break completion notification routes to Done; stale/duplicate actions are ignored |
| I17 | Add notification Restart | Valid action starts one Focus; foreground/background/relaunch paths are checked |
| I18 | Show permission status and useful failure guidance | Denied alerts and scheduling errors do not block timer flow; Settings guidance is available |
| I19 | Verify accessibility and visual resilience | Check VoiceOver, Dynamic Type, contrast, focus/order, control labels and largest supported text sizes |
| I20 | Supply final app icon | Complete the 1024×1024 artwork slot and verify appearance in the app/launcher |
| I21 | Prepare local release notes and verification checklist | Record version /build, privacy behavior, known limits, device checks, and reproducible build steps |
| I22 | Decide and implement launch-state policy (added after I01) | Record in the [mission](mission.md) whether each state (running, paused, waiting for Break confirmation, completed) is restored or reset on relaunch, keeping deadline recovery for running phases unless the decision changes that invariant. Behavior matches the decision for every state, with tests and a manual relaunch check; I01 observed the app reopening in waiting-for-Break. Note: whne timer is On, exit and re-start before timer ends - gets us back to phase + correct time to end. |
| I23 | Make the active timer obvious (added after I01) | Design note in the phase spec, then the SwiftUI change: Focus and Break are visually distinct in running, paused, and waiting states. User-reported simulator screenshots show the active timer is identifiable at a glance; accessibility labels name it |
| I24 | Design Focus-end and Break-end states (added after I01) | Design note in the phase spec, then the SwiftUI change: Focus end (waiting for Break confirmation) and Break end each have a clearly distinct presentation with the next action visible. It supplies the Break-end presentation I13 to I15 build on, so schedule it before I13 if that is wanted; user-reported screenshots confirm both ends are unmistakable |

Add focused XCTest coverage with each behavior change after the test target exists. Use native UI tests for meaningful control/state interactions; use manual simulator and physical-device checks for OS notification behavior. Unit success does not prove delivery under system restrictions. If baseline checks fail, specify and resolve the smallest blocking defect before proceeding.

## Later decisions, not scheduled implementation

App Store submission, store screenshots/privacy forms, signing/distribution automation, and release policy require a future decision. Custom sound, alternative defaults, fractional-minute input, broader device/OS support, sync, and analytics are not part of this roadmap. The current approved defaults stay one minute each, whole-minute UI, iPhone portrait, iOS 26+.

## Completion discipline

Mark each phase planned, in progress, or verified in its phase document; reference the implementing commit and actual acceptance evidence. When a phase is verified and pushed, move its row from the forward table to the completed table with the date, phase spec link, and pushed commit. Keep this roadmap's status current. Invoke `$update-changelog` manually before merging. A spec update alone is not proof that code exists or acceptance checks passed.

## References

[Mission and invariants](mission.md), [stack and build command](tech-stack.md), [archived iOS status](../history/focustimer_ios_spec.md), [original recommendations](../history/FOCUSTIMER_SPEC.md).
