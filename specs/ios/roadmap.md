# iOS roadmap

Status: accepted high-level order on 2026-10-16; dependencies and parallel-work rules added 2026-11-02. Baseline `6e00429`. Completed phases are listed in the table below; the others are unstarted; documentation approval does not mark implementation complete.

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
| I07 | Saved and started durations rounded to whole minutes and clamped to Focus 1–240 min and Break 1–120 min (shared with the UI); invalid saved timer state repaired at launch with a correction notice (48 tests: 47 passed, 1 expected failure for I12; agent-run iPhone 17 Pro iOS 26.5, user-reported Cmd+U and notice check) | 2026-10-20 | [I07-enforce-invariants](phases/I07-enforce-invariants.md) | `627f7d5` on `main` |
| I08 | `schemaVersion` key added; records saved before versioning are migrated at launch with settings and timer state kept, and saved as version 1; a newer or unreadable version is left untouched for I09 (55 tests: 54 passed, 1 expected failure for I12; agent-run iPhone 17 Pro iOS 26.5, user-reported Cmd+U and an upgrade check of real pre-I08 data) | 2026-10-20 | [I08-schema-versioning](phases/I08-schema-versioning.md) | `7625c58` on `main` |
| I09 | Unreadable `config` or `state` replaced with defaults or idle, the other record kept, correction notice shown, pending alerts cancelled; a newer or unreadable `schemaVersion` keeps defaults in memory and writes nothing at launch, and the first save writes both records and the current version (64 tests: 63 passed, 1 expected failure for I12; agent-run iPhone 17 Pro iOS 26.5, user-reported Cmd+U and two seeded relaunch checks) | 2026-10-24 | [I09-recover-saved-records](phases/I09-recover-saved-records.md) | `0839457` on `main` |
| I10 | Each Focus → Break cycle has a saved cycle ID carried in completion notifications; the Focus OK starts Break only for a matching ID, and stale, missing, or repeated actions change nothing; saved data moved to schema version 2 (80 tests: 79 passed, 1 expected failure for I12; agent-run iPhone 17 Pro iOS 26.5, user-reported Cmd+U and an upgrade check). Manual stale-alert tap check deferred, then superseded by the I11 Notification Center check | 2026-10-26 | [I10-cycle-identity](phases/I10-cycle-identity.md) | `0d7b35c` on `main` |
| I11 | Delivered alerts removed once they no longer match the timer (Break start removes the Focus alert; Cancel and a new Focus cancel pending and remove delivered alerts; launch and activation clean up by phase); fixed a crash, present since the app was added, when tapping a notification's OK; Codex review finding fixed (new Focus cancels pending requests) (95 tests: 94 passed, 1 expected failure for I12; agent-run iPhone 17 Pro iOS 26.5, user-reported Cmd+U and Notification Center check) | 2026-10-26 | [I11-clean-up-alerts](phases/I11-clean-up-alerts.md) | `7bd31bc` on `main` |
| I12 | Pause at or after expiry completes the phase (known issue fixed); after a backward clock jump a running deadline is capped at now + the phase length; an over-long saved paused time is clamped with the notice; Codex review finding fixed (launch reconciles before showing the countdown, so extreme saved deadlines no longer crash) (109 tests, all passing, 0 known issues; agent-run iPhone 17 Pro iOS 26.5, user-reported Cmd+U). Known limit: an unreadable config caps a longer running phase to the default | 2026-10-27 | [I12-expiry-clock-edges](phases/I12-expiry-clock-edges.md) | `1782b7b` on `main` |
| I13 | A finished Break enters a saved `completed` phase that keeps the cycle ID, has no deadline, survives relaunch, and keeps the Break alert; Start Focus or Cancel leaves it until I14 and I15; saved data at schema version 3 (135 tests, all passing; agent-run iPhone 17 Pro iOS 26.5, user-reported Cmd+U and upgrade and relaunch check) | 2026-10-27 | [I13-completed-state](phases/I13-completed-state.md) | `7eb24d5` on `main` |
| I24 | Focus end and Break end have their own presentation (amber "Focus complete" with Start Break; green "Cycle complete" with Start Focus); Break end is an unsaved presentation until I13; done before I13 by user decision (121 tests, all passing; agent screenshots of both ends; user-reported Cmd+U and full-cycle check) | 2026-10-27 | [I24-end-states](phases/I24-end-states.md) | `a660f4b` on `main` |

## Small forward phases

Before code, write a short phase spec at `specs/ios/phases/Ixx-short-name.md` covering intended behavior, non-goals, affected components, and concrete acceptance checks. Update it with evidence and limitations after verification. Split a phase further if it cannot fit a focused, reviewable change; do not bundle later features into a refactor.

### Running phases in parallel

Phases can run at the same time, each in its own branch and git worktree (see [Parallel work in AGENTS.md](../../AGENTS.md#parallel-work)). The table below says when that is safe:

- **Ready:** a phase is ready when every phase in its *Depends on* column is in the completed table. The column is the only gate: ordering rules such as "I25 first" are written into it, not left to prose.
- **Taken:** a phase is taken while its claim ref `refs/claims/Ixx` exists, or a `feat/Ixx-*` branch exists and the phase is not yet in the completed table, or its spec on `main` says in progress. A taken phase whose spec cannot be read (no worktree with the spec and none on its branch) is unavailable until the user clarifies it. Do not start a taken phase; continue it instead. Claims are made, rechecked, and released as described in [Parallel work in AGENTS.md](../../AGENTS.md#parallel-work).
- **Overlap:** two ready phases can run in parallel when their *Touches* columns share no entry. If they share one, run them one after the other, or start the second only with the user's agreement and expect the later merge to need conflict resolution.
- **Saved format:** a phase marked *may change* takes the next free `schemaVersion` when it merges, not when it starts (see AGENTS.md).

*Touches* lists the main files a phase is expected to change: Swift files under `ios/FocusTimer/FocusTimer/`, `Tests` for `ios/FocusTimer/FocusTimerTests/`, `Assets` for `Assets.xcassets`, and `docs` for files under `specs/` other than the phase spec. Every phase also adds to the shared records (`CHANGELOG.md`, the roadmap after merging, and the "Since phase" sentences in the mission and tech stack); AGENTS.md says how to keep those from conflicting, so they are not listed. The *Depends on* and *Touches* entries are planning estimates: `$start-phase` confirms them with the user and records the final values in the phase spec.

| Phase | Small deliverable | Exit check | Depends on | Touches | Saved format |
| --- | --- | --- | --- | --- | --- |
| I25 | Split the unit tests by area (added for parallel work) | `FocusTimerTests.swift` is split into one `*Tests.swift` file per area, with shared helpers in `TestDoubles.swift`; no test logic changes; the executed test count from the result bundle equals the count before the split. Run before parallel code phases so they stop editing one shared test file | — | Tests | no change |
| I14 | Add in-app Done | Completed → idle; configuration survives; repeated Done is harmless | I13, I25 | TimerStore, ContentView, Tests | no change |
| I15 | Add in-app Restart | Completed → new Focus with saved durations and new cycle identity; Break still needs confirmation | I13, I25 | TimerStore, ContentView, Tests | no change |
| I16 | Add notification Done | Valid Break completion notification routes to Done; stale/duplicate actions are ignored | I14 | NotificationScheduler, FocusTimerApp, TimerStore, Tests | no change |
| I17 | Add notification Restart | Valid action starts one Focus; foreground/background/relaunch paths are checked | I15, I16 | NotificationScheduler, FocusTimerApp, TimerStore, Tests | no change |
| I18 | Show permission status and useful failure guidance | Denied alerts and scheduling errors do not block timer flow; Settings guidance is available | I25 | NotificationScheduler, FocusTimerApp, ContentView, TimerStore, Tests | no change |
| I19 | Verify accessibility and visual resilience | Check VoiceOver, Dynamic Type, contrast, focus/order, control labels and largest supported text sizes | I14, I15, I18, I23 (checks the final screens) | ContentView | no change |
| I20 | Supply final app icon | Complete the 1024×1024 artwork slot and verify appearance in the app/launcher | — | Assets | no change |
| I21 | Prepare local release notes and verification checklist | Record version /build, privacy behavior, known limits, device checks, and reproducible build steps | All other forward phases (records the final behavior) | docs | no change |
| I22 | Decide and implement launch-state policy (added after I01) | Record in the [mission](mission.md) whether each state (running, paused, waiting for Break confirmation, completed) is restored or reset on relaunch, keeping deadline recovery for running phases unless the decision changes that invariant. Behavior matches the decision for every state, with tests and a manual relaunch check; I01 observed the app reopening in waiting-for-Break. Note: whne timer is On, exit and re-start before timer ends - gets us back to phase + correct time to end. | I13, I25 | TimerStore, Tests, docs | may change |
| I23 | Make the active timer obvious (added after I01) | Design note in the phase spec, then the SwiftUI change: Focus and Break are visually distinct in running, paused, and waiting states. User-reported simulator screenshots show the active timer is identifiable at a glance; accessibility labels name it | — | ContentView | no change |

I25 changes every test file, so every phase that touches `Tests` depends on it (I16 and I17 through I14 and I15); only I20 and I23 can run alongside it. After I25, each phase puts its new tests in a test file of its own, and `Tests` counts as an overlap only when two phases change the same existing test file. Then up to three phases can run at once without sharing files: I20, one of the ready `TimerStore` phases (I14, I15, I18, I22), and I23 when that `TimerStore` phase is I22 (I14, I15, and I18 also change `ContentView`). I14 to I18 and I22 all change `TimerStore`, so they run one after another.

Add focused Swift Testing unit tests (`import Testing`) with each behavior change. Use native XCTest UI tests for meaningful control/state interactions; use manual simulator and physical-device checks for OS notification behavior. Unit success does not prove delivery under system restrictions. If baseline checks fail, specify and resolve the smallest blocking defect before proceeding.

## Later decisions, not scheduled implementation

App Store submission, store screenshots/privacy forms, signing/distribution automation, and release policy require a future decision. Custom sound, alternative defaults, fractional-minute input, broader device/OS support, sync, and analytics are not part of this roadmap. The current approved defaults stay one minute each, whole-minute UI, iPhone portrait, iOS 26+.

## Completion discipline

Mark each phase planned, in progress, or verified in its phase document; reference the implementing commit and actual acceptance evidence. When a phase is verified and pushed, move its row from the forward table to the completed table with the date, phase spec link, and pushed commit. Do that after the merge, in a `chore/roadmap-after-Ixx` branch from `main`, while still holding the integration claim (see AGENTS.md); phase branches do not edit this roadmap, so parallel phases never conflict here. A UI phase merged after I19 repeats the I19 accessibility checks for the screens it adds or changes. Keep this roadmap's status current. Invoke `$update-changelog` manually before merging. A spec update alone is not proof that code exists or acceptance checks passed.

## References

[Mission and invariants](mission.md), [stack and build command](tech-stack.md), [archived iOS status](../history/focustimer_ios_spec.md), [original recommendations](../history/FOCUSTIMER_SPEC.md).
