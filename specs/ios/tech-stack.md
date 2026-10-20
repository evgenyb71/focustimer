# iOS tech stack

Status: baseline and accepted constraints as of 2026-10-16; updated 2026-10-20 for the injected clock and store (phase I03-I04) and the notification boundary and unit-test target (phase I05). Planned changes are explicitly marked.

| Area | Accepted stack and current implementation |
| --- | --- |
| Platform | Native iPhone only, portrait, minimum iOS 26.0 |
| Toolchain | Swift language mode 6; project baseline created for Xcode 26.5 / iOS 26 SDK |
| UI | SwiftUI `ContentView`, native SF Symbols and asset catalog |
| State | `@MainActor TimerStore: ObservableObject`; `TimerStore.shared` is the app's single instance; the internal initializer takes an injected `Clock` and `KeyValueStore` (defaults `SystemClock()` and `UserDefaults.standard`) |
| Persistence | Foundation Codable JSON Data in UserDefaults keys `config` and `state` |
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
- `ContentView.swift`: durations, status, and controls; `Assets.xcassets`: color/icon slots.

## Gaps that guide future design

Since phase [I03-I04](phases/I03-I04-inject-clock-and-store.md), `TimerStore` reads the current time only through an injected `Clock` (`Clock.swift`) and reads and writes `config` and `state` only through one injected `KeyValueStore` (`KeyValueStore.swift`, with a `UserDefaults` conformance). Since phase [I05](phases/I05-notification-boundary-tests.md), `TimerStore` also schedules and cancels completions through an injected `NotificationScheduling` (`SystemNotificationScheduler` in production), which computes the trigger interval from the clock time `TimerStore` passes in; the app delegate's category setup and authorization request remain static. The unit tests construct `TimerStore` with test doubles for all three boundaries. Keep boundaries small; retain a single authoritative transition owner without introducing a large framework.

Decoding failure falls back to defaults. Since phase [I07](phases/I07-enforce-invariants.md), successfully decoded data is validated on load: durations are rounded to whole minutes and clamped to `Configuration.focusRange` and `breakRange`, and timer state that breaks the mission invariants is repaired (stray fields removed; a running phase without a deadline becomes idle; a paused phase without positive remaining time is treated as expired). Repairs are persisted and announced through `statusMessage`. There is no schema version, migration, cycle/event identity, completed state, or delivered-notification cleanup. Stable notification IDs `focusComplete`/`breakComplete` replace pending requests but do not identify a cycle. The delegate checks the action string and current phase without validating notification provenance. Notification authorization and scheduling failures are not surfaced.

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
