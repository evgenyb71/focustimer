# iOS tech stack

Status: baseline and accepted constraints as of 2026-10-16; updated 2026-10-20 for the injected clock and store (phase I03-I04). Planned changes are explicitly marked.

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
| Testing | No active test targets today; planned native XCTest unit and UI tests |

## Source map

- `ios/FocusTimer/FocusTimer.xcodeproj`: scheme `FocusTimer`, bundle `com.ebochkarev.FocusTimer`, automatic signing for physical devices. Simulator builds do not require signing.
- `ios/FocusTimer/FocusTimer/TimerStore.swift`: configuration, transitions, persistence, countdown, and deadline reconciliation.
- `Clock.swift`: `Clock` protocol and `SystemClock` (current time); `KeyValueStore.swift`: storage protocol and `UserDefaults` conformance.
- `NotificationScheduler.swift`: local notification setup and scheduling.
- `FocusTimerApp.swift`: application entry, scene lifecycle, notification response delegation.
- `ContentView.swift`: durations, status, and controls; `Assets.xcassets`: color/icon slots.

## Gaps that guide future design

Since phase [I03-I04](phases/I03-I04-inject-clock-and-store.md), `TimerStore` reads the current time only through an injected `Clock` (`Clock.swift`) and reads and writes `config` and `state` only through one injected `KeyValueStore` (`KeyValueStore.swift`, with a `UserDefaults` conformance). No test target uses these yet. `NotificationScheduler` still computes its trigger interval from the live clock and is called through static methods; its boundary is planned for I05. Keep boundaries small; retain a single authoritative transition owner without introducing a large framework.

Decoding failure falls back to defaults, but successfully decoded data is not semantically validated. There is no schema version, migration, cycle/event identity, completed state, or delivered-notification cleanup. Stable notification IDs `focusComplete`/`breakComplete` replace pending requests but do not identify a cycle. The delegate checks the action string and current phase without validating notification provenance. Notification authorization and scheduling failures are not surfaced.

No perpetual background timer is assumed: iOS can suspend the process. Persisted deadlines support reconciliation on return; the OS schedules notifications independently. Notification delivery does not itself update suspended in-memory state.

## Development commands

Open `ios/FocusTimer/FocusTimer.xcodeproj` in Xcode 26.5 or later, select the FocusTimer scheme and an available iOS 26+ iPhone simulator, and Run.

From the repository root, build without signing:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FocusTimerDerivedData CODE_SIGNING_ALLOWED=NO build
```

Select the full Xcode developer directory if the machine defaults to Command Line Tools. The command is documented here, not rerun as part of the documentation migration. No `npm` commands, package resolution, or code generation apply.

When test targets are added, document the exact `xcodebuild test` command and an installed simulator destination in this file and AGENTS.md. Keep fake-clock/storage/notification tests separate from real OS notification/lifecycle checks. Do not report automated tests as available until configured and run.

## References

[Mission](mission.md), [roadmap](roadmap.md), [archived implementation status](../history/focustimer_ios_spec.md).
