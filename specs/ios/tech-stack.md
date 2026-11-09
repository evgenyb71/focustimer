# iOS tech stack

Build and test commands are in [AGENTS.md](../../AGENTS.md#build-and-verification).

| Area | Choice |
| --- | --- |
| Platform | Native iPhone only, portrait, minimum iOS 26.0 |
| Toolchain | Swift 6 language mode; Xcode 26.5 or later |
| UI | SwiftUI `ContentView`, native SF Symbols, asset catalog |
| State | `@MainActor TimerStore: ObservableObject`; `TimerStore.shared` is the app's single instance |
| Persistence | Codable JSON in UserDefaults keys `config` and `state`, plus a JSON-encoded integer `schemaVersion` (current version 3) |
| Timing | Foundation `Date` deadlines; one-second `Timer` for display and reconciliation |
| Notifications | UserNotifications local requests, categories, and actions; UIKit app delegate bridge |
| Lifecycle | SwiftUI `scenePhase` activation and launch reconciliation |
| Dependencies | Apple frameworks only |
| Testing | `FocusTimerTests` target (Swift Testing, hosted by the app); XCTest reserved for planned UI tests |

## Source map

Under `ios/FocusTimer/`:

- `FocusTimer.xcodeproj`: scheme `FocusTimer`, bundle `com.ebochkarev.FocusTimer`, automatic signing for physical devices. Simulator builds need no signing.
- `FocusTimer/TimerStore.swift`: configuration, transitions, persistence, migration, repair, countdown, and deadline reconciliation.
- `FocusTimer/Clock.swift`, `KeyValueStore.swift`: the injected time and storage boundaries.
- `FocusTimer/NotificationScheduler.swift`: identifiers, categories, alert content, and authorization; the injected `NotificationScheduling` boundary and `SystemNotificationScheduler`.
- `FocusTimer/FocusTimerApp.swift`: entry point, scene lifecycle, notification response delegation.
- `FocusTimer/ContentView.swift`: durations, status, and controls, with the end-state presentation driven by `TimerStore.endState`. `Assets.xcassets`: color and icon slots.
- `FocusTimerTests/`: one `*Tests.swift` file per suite; `TestDoubles.swift` has the fake clock, in-memory store, recording notification scheduler, and test arguments shared across suites.

`scripts/test.sh` runs the unit tests and checks the executed count.

## Design notes

Things the code does not make obvious:

- `TimerStore` is the single owner of transitions. Time, storage, and notifications go through three small injected boundaries, so tests use doubles for all of them. Keep these small; do not add a framework. The app delegate's category setup and authorization request remain static.
- `schemaVersion` is read before decoding; a missing key means version 0. Migrations run step by step (`migrations`). A step can change no records and only raise the version, which makes older builds leave newer data alone.
- `cycleID` is created on Focus start and kept through completed; it is removed on Cancel, Done, and a launch reset, and a new Focus replaces it.
- The launch reset goes by the saved phase, before reconciling. A saved waiting or completed state becomes idle, while a running phase that expired while closed reconciles to its end screen. That screen is saved, so the next launch resets it.
- Notification IDs `focusComplete` and `breakComplete` identify alerts for removal, not cycles. The cycle is in `userInfo["cycleID"]`.
- Two categories are registered together, because setting categories replaces the whole set: `FOCUS_COMPLETE` with OK, which opens the app, and `BREAK_COMPLETE` with Done, which runs in the background. `NotificationScheduler.content(for:cycleID:)` builds both alerts, so tests check the content without the notification center. The delegate routes each action to a cycle-checked `TimerStore` method, which checks the cycle before reconciling so that a rejected action cannot reconcile a newer cycle.
- The deadline cap uses the current configuration. If an unreadable `config` was replaced with defaults while a longer phase ran, that phase shortens to the default length.
- iOS can suspend the process, so no background timer is assumed. Persisted deadlines reconcile on return, and notification delivery does not update suspended in-memory state.
- Notification authorization and scheduling failures are not surfaced yet (I18).
