# FocusTimer (iOS)

SwiftUI single-screen app that mirrors the Chrome extension flow: Focus then Break, with a confirmation between phases, pause/resume, cancel, persisted state, and local notifications when phases complete.

## Features
- Two-phase sequential timer: Focus → confirm → Break.
- Pause/resume and cancel/reset.
- Persists configuration and state in `UserDefaults` so closing the app doesn’t lose progress.
- Local notifications on Focus complete (prompt to start Break) and Break complete.
- Simple badge-like status via on-screen labels; single-screen SwiftUI UI.

## Structure
- `FocusTimerApp.swift` — App entry point.
- `ContentView.swift` — UI + `TimerViewModel` with state machine, timers, storage, and notifications.
- `Info.plist` — Basic identifiers and notification usage string.

## Building / Running
1) Open `ios/FocusTimer` in Xcode.
2) Set your bundle identifier and signing team in the project settings (Info.plist currently uses `com.example.FocusTimer`).
3) Run on a device or simulator. Grant notification permission on first launch.

## Behavior Notes
- Timers use `Timer` + stored `endDate`/`remainingSeconds`; on launch or after pause/resume, timing continues from timestamps.
- Local notifications are scheduled for Focus and Break completion; a non-timed notification is used when waiting-for-confirm to start Break.
- Background execution is limited by iOS; timers rely on timestamps/notifications rather than continuous background execution.

## Next Steps (optional)
- Add background task handling and refine notification actions (e.g., action buttons to start Break).
- Add app icon and branding.
- Share configuration/state model across Chrome and iOS if desired.
