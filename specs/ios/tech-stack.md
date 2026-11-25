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
| Testing | `FocusTimerTests` target (Swift Testing, hosted by the app), scheme FocusTimer; `FocusTimerUITests` target (XCTest UI tests: the accessibility audit), scheme FocusTimer UI Tests |

## Source map

Under `ios/FocusTimer/`:

- `FocusTimer.xcodeproj`: scheme `FocusTimer`, bundle `com.ebochkarev.FocusTimer`, automatic signing for physical devices. Simulator builds need no signing.
- `FocusTimer/TimerStore.swift`: configuration, transitions, persistence, migration, repair, countdown, and deadline reconciliation.
- `FocusTimer/Clock.swift`, `KeyValueStore.swift`: the injected time and storage boundaries.
- `FocusTimer/NotificationScheduler.swift`: identifiers, categories, alert content, and authorization; the injected `NotificationScheduling` boundary and `SystemNotificationScheduler`.
- `FocusTimer/FocusTimerApp.swift`: entry point, scene lifecycle, notification response delegation.
- `FocusTimer/ContentView.swift`: durations, status, and controls, with the end-state presentation driven by `TimerStore.endState` and the running or paused presentation by `TimerStore.activeTimer`; phase symbols live in the view. `FocusTimer/Palette.swift`: every colour with its light and dark value, and the contrast maths that `PaletteContrastTests` uses. Dynamic colours resolve on SwiftUI's background render thread too, so their provider must stay nonisolated. `Assets.xcassets`: accent colour, and the app icon in light, dark, and tinted PNGs.
- `FocusTimerUITests/AccessibilityAuditTests.swift`: Apple's accessibility audit on idle, Focus running, paused, waiting for Break, and Cycle complete, at the default and largest text size. Each screen is reached by seeding `config`, `state`, and `schemaVersion` through launch arguments for that launch; the app has no test code.
- `FocusTimerTests/`: one `*Tests.swift` file per suite; `TestDoubles.swift` has the fake clock, in-memory store, recording notification scheduler, and test arguments shared across suites.

`scripts/test.sh` runs the unit tests and checks the executed count; `scripts/test.sh --ui` runs the UI tests the same way. `scripts/make-app-icon.swift` redraws the three icon PNGs with CoreGraphics (`swift scripts/make-app-icon.swift`); it is not part of the build. `scripts/debug-minute.sh` sets the Debug-only short minute on a simulator, or sets it back to 60 with `off`.

## Design notes

Things the code does not make obvious:

- `TimerStore` is the single owner of transitions. Time, storage, and notifications go through three small injected boundaries, so tests use doubles for all of them. Keep these small; do not add a framework. The app delegate's category setup and authorization request remain static.
- `schemaVersion` is read before decoding; a missing key means version 0. Migrations run step by step (`migrations`). A step can change no records and only raise the version, which makes older builds leave newer data alone.
- `cycleID` is created on Focus start and kept through completed; it is removed on Cancel, Done, and a launch reset, and a new Focus replaces it.
- The launch reset goes by the saved phase, before reconciling. A saved waiting or completed state becomes idle, while a running phase that expired while closed reconciles to its end screen. That screen is saved, so the next launch resets it.
- Notification IDs `focusComplete` and `breakComplete` identify alerts for removal, not cycles. The cycle is in `userInfo["cycleID"]`.
- The delegate presents a foreground alert with `NotificationScheduler.foregroundPresentation`, the sound only. iOS asks only while the app is in the foreground, so background delivery needs no state check.
- Two categories are registered together, because setting categories replaces the whole set: `FOCUS_COMPLETE` with OK, which opens the app, and `BREAK_COMPLETE` with Restart and Done, which run in the background. `NotificationScheduler.content(for:cycleID:)` builds both alerts, so tests check the content without the notification center. The delegate routes each action to a cycle-checked `TimerStore` method, which checks the cycle before reconciling so that a rejected action cannot reconcile a newer cycle.
- `TimerStore` takes `secondsPerMinute`, 60 unless a Debug build reads `debugSecondsPerMinute` from the app's defaults at launch; values outside 1–60 mean 60. `Configuration.runLength(of:secondsPerMinute:)` turns minutes into the run length for starting a phase, the deadline cap, and the paused clamp. Configuration and saved values stay in whole minutes, and Release builds contain neither the setting nor its key.
- The deadline cap uses the current configuration. If an unreadable `config` was replaced with defaults while a longer phase ran, that phase shortens to the default length.
- The store's one-second ticker only reconciles. It is on by default and stops when the store is released (`isolated deinit`, because the run loop keeps a scheduled timer). Unit tests pass `ticksAutomatically: false`, except those about the ticker.
- Cancel and Done share `resetToIdle()`; Done first checks for completed and saves the durations.
- iOS can suspend the process, so no background timer is assumed. Persisted deadlines reconcile on return, and notification delivery does not update suspended in-memory state.
- Permission status comes from `NotificationScheduling.authorizationStatus()`, read without blocking at launch, after the launch prompt, and on activation, applying only the latest read; only `denied` shows the hint, and it is not saved. `scheduleCompletion` submits the add inline, so later removals reach the center after it, and takes an `onFailure` handler that runs on the main actor; `notificationsNotAllowed` is not reported. `TimerStore` shows the notice only if the phase, cycle, and deadline are still the ones scheduled and alerts are not known to be denied. Removal and category-setup failures are not surfaced.
