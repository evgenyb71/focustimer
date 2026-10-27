# iOS tech stack

Status: baseline and accepted constraints as of 2026-10-16; updated 2026-10-24 for recovery of unreadable records (I09), 2026-10-20 for the injected clock and store (phase I03-I04) and the notification boundary and unit-test target (phase I05). Planned changes are explicitly marked.

| Area | Accepted stack and current implementation |
| --- | --- |
| Platform | Native iPhone only, portrait, minimum iOS 26.0 |
| Toolchain | Swift language mode 6; project baseline created for Xcode 26.5 / iOS 26 SDK |
| UI | SwiftUI `ContentView`, native SF Symbols and asset catalog |
| State | `@MainActor TimerStore: ObservableObject`; `TimerStore.shared` is the app's single instance; the internal initializer takes an injected `Clock` and `KeyValueStore` (defaults `SystemClock()` and `UserDefaults.standard`) |
| Persistence | Foundation Codable JSON Data in UserDefaults keys `config` and `state`, plus a JSON-encoded integer `schemaVersion` (version 1 since I08, version 2 since I10, which adds `cycleID` to `state`, current version 3 since I13, which allows the `completed` phase) |
| Timing | Foundation Date deadlines; one-second Timer for active display/reconciliation |
| Notifications | UserNotifications local requests/categories/actions; UIKit app delegate bridge |
| Lifecycle | SwiftUI scenePhase activation and launch reconciliation |
| Dependencies | Apple frameworks only; no external packages or backend |
| Testing | `FocusTimerTests` unit-test target (Swift Testing, hosted by the app, iOS 26.0, Swift 6); XCTest reserved for planned UI tests |

## Source map

- `ios/FocusTimer/FocusTimer.xcodeproj`: scheme `FocusTimer`, bundle `com.ebochkarev.FocusTimer`, automatic signing for physical devices. Simulator builds do not require signing.
- `ios/FocusTimer/FocusTimer/TimerStore.swift`: configuration, transitions, persistence, countdown, and deadline reconciliation.
- `Clock.swift`: `Clock` protocol and `SystemClock` (current time); `KeyValueStore.swift`: storage protocol and `UserDefaults` conformance.
- `NotificationScheduler.swift`: notification identifiers, category setup, and authorization (`NotificationScheduler`); the `NotificationScheduling` protocol and its `SystemNotificationScheduler` implementation for scheduling and cancelling completions.
- `ios/FocusTimer/FocusTimerTests/`: Swift Testing unit tests (`FocusTimerTests.swift`) and test doubles (`TestDoubles.swift`).
- `FocusTimerApp.swift`: application entry, scene lifecycle, notification response delegation.
- `ContentView.swift`: durations, status, and controls, including the end-state presentation driven by `TimerStore.endState` (since I24); `Assets.xcassets`: color/icon slots.

## Gaps that guide future design

Since phase [I03-I04](phases/I03-I04-inject-clock-and-store.md), `TimerStore` reads the current time only through an injected `Clock` (`Clock.swift`) and reads and writes `config` and `state` only through one injected `KeyValueStore` (`KeyValueStore.swift`, with a `UserDefaults` conformance). Since phase [I05](phases/I05-notification-boundary-tests.md), `TimerStore` also schedules and cancels completions through an injected `NotificationScheduling` (`SystemNotificationScheduler` in production), which computes the trigger interval from the clock time `TimerStore` passes in; the app delegate's category setup and authorization request remain static. The unit tests construct `TimerStore` with test doubles for all three boundaries. Keep boundaries small; retain a single authoritative transition owner without introducing a large framework.

Decoding failure falls back to defaults. Since phase [I07](phases/I07-enforce-invariants.md), successfully decoded data is validated on load: durations are rounded to whole minutes and clamped to `Configuration.focusRange` and `breakRange`, and timer state that breaks the mission invariants is repaired (stray fields removed; a running phase without a deadline becomes idle; a paused phase without positive remaining time is treated as expired). Repairs are persisted and announced through `statusMessage`. Since phase [I08](phases/I08-schema-versioning.md), `TimerStore` reads `schemaVersion` before decoding. A missing key means version 0, the unversioned format. Older versions are migrated step by step (`migrations`; 0 → 1 changes no record content) and the new version is saved at launch. Since phase [I09](phases/I09-recover-saved-records.md), a saved `config` or `state` that is present but cannot be decoded is replaced at launch (defaults for `config`, idle for `state`) with the correction notice, and the other record is kept; a replaced state cancels pending completions. A newer, negative, or unreadable version loads defaults in memory, writes nothing at launch, and shows the same notice; the first later save writes both records and the current version. Since phase [I10](phases/I10-cycle-identity.md), `TimerState.cycleID` (a UUID) identifies each cycle: it is created on Focus start and kept through waiting and Break. Since I13 a finished Break keeps it in the completed phase; it is removed only on Cancel (idle), and a new Focus replaces it. The 1 → 2 migration gives a saved active cycle an ID; repair adds a missing ID to an active phase (with the correction notice) and removes one from idle. Completion notifications carry the ID in `userInfo` under `cycleID`, and the delegate passes it to `TimerStore.startBreakFromNotification(cycleID:)`, which reconciles and then starts Break only for a matching ID. Since phase [I11](phases/I11-clean-up-alerts.md), `NotificationScheduling` also removes delivered alerts (`removeDeliveredCompletion(for:)`, `removeAllDeliveredCompletions()`): Break start removes the delivered Focus alert, Cancel and Focus start remove all, Break completion cancels only the pending Break request, and `TimerStore.activate()` (called on scene activation) and launch remove delivered alerts that do not match the phase. Stable notification IDs `focusComplete`/`breakComplete` identify the alerts for removal; they do not identify a cycle. Since phase [I13](phases/I13-completed-state.md), `Phase.completed` follows a finished Break: it keeps the cycle ID, has no deadline or paused time, is saved and restored on relaunch, and keeps the delivered Break alert on launch and activation. The 2 → 3 migration changes no records; repair removes stray timing fields from completed and adds a missing cycle ID, and a paused Break without time left is repaired to completed. The I24 `breakJustFinished` flag is removed. Notification authorization and scheduling failures are not surfaced.

Since phase [I12](phases/I12-expiry-clock-edges.md), `pauseOrResume()` reconciles before pausing, so a phase at or after its deadline completes; `reconcileWithCurrentTime()` caps a running deadline that is more than the phase's configured length away (`Configuration.duration(of:)`) at now + that length, saves it, and reschedules the alert; and launch clamps an over-long paused time (`TimerState.clampingPausedTime(to:)`) with the correction notice. The cap uses the current configuration, so if an unreadable `config` was replaced with defaults while a longer phase ran, that phase is shortened to the default length. Deadlines remain wall-clock `Date`s.

No perpetual background timer is assumed: iOS can suspend the process. Persisted deadlines support reconciliation on return; the OS schedules notifications independently. Notification delivery does not itself update suspended in-memory state.

## Development commands

Open `ios/FocusTimer/FocusTimer.xcodeproj` in Xcode 26.5 or later, select the FocusTimer scheme and an available iOS 26+ iPhone simulator, and Run.

From the repository root, build without signing:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FocusTimerDerivedData CODE_SIGNING_ALLOWED=NO build
```

Select the full Xcode developer directory if the machine defaults to Command Line Tools. The command is documented here, not rerun as part of the documentation migration. No `npm` commands, package resolution, or code generation apply.

Run the unit tests from the repository root on an installed iOS 26+ simulator (agents have used iPhone 17 Pro, iOS 26.5), or with Product > Test in Xcode:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath /tmp/FocusTimerTests-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
```

Confirm the executed test count with `xcrun xcresulttool get test-results summary --path <result bundle>`; a success banner with 0 tests is possible when the target's synchronized folder is not attached. Tests live in `ios/FocusTimer/FocusTimerTests/` and use `TestDoubles.swift` (fake clock, in-memory store, recording notification scheduler). Keep these deterministic tests separate from real OS notification and lifecycle checks, which stay manual.

## References

[Mission](mission.md), [roadmap](roadmap.md), [archived implementation status](../history/focustimer_ios_spec.md).
