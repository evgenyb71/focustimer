# FocusTimer for iPhone — Implementation Status

Updated: 2026-07-10

This file tracks the new iPhone-only project in `ios/FocusTimer`. Its functional scope is intentionally limited to behavior already implemented by the Chrome extension and documented in `FOCUSTIMER_SPEC.md`.

## Project baseline

- [x] Brand-new Xcode project at `ios/FocusTimer/FocusTimer.xcodeproj`.
- [x] SwiftUI application with no third-party dependencies.
- [x] Created for Xcode 26.5 and the iOS 26 SDK.
- [x] Swift language version 6.
- [x] Minimum deployment target iOS 26.0.
- [x] `TARGETED_DEVICE_FAMILY = 1` so the target is iPhone only.
- [x] Portrait-only iPhone interface.
- [x] Generated Info.plist and launch screen configuration.
- [ ] Final branded 1024 × 1024 app icon. The asset slot exists, but no production artwork was supplied.

## Implemented Chrome-parity behavior

- [x] Configurable Focus and Break durations, represented internally in seconds.
- [x] Defaults of one minute for Focus and one minute for Break, matching Chrome.
- [x] Sequential flow: idle → Focus → explicit confirmation → Break → idle.
- [x] Start button begins Focus only from idle.
- [x] Start Break button is available only after Focus completes.
- [x] Focus and Break countdown display updates once per second while the app is active.
- [x] Pause and resume work during either running phase.
- [x] Cancel/reset works from all phases.
- [x] Duration controls are disabled outside idle.
- [x] Configuration and timer state persist in `UserDefaults`.
- [x] Running timers use absolute `Date` deadlines rather than relying on background ticks.
- [x] The app reconciles expired deadlines on launch and whenever it becomes active.
- [x] Local notifications are scheduled for Focus and Break completion.
- [x] Notifications request alert and sound permission.
- [x] Focus completion notification has an `OK` action that opens the app and starts Break.
- [x] Foreground notifications are presented as banner/list with sound.
- [x] Pausing or cancelling removes pending completion notifications so an inactive timer does not fire.
- [x] Warm, card-based visual treatment mirrors the current Chrome popup.
- [x] Buttons use native accessible symbols and accessibility labels.

## State and persistence mapping

The iPhone state intentionally mirrors the Chrome storage model:

| iPhone value | Chrome equivalent | Meaning |
|---|---|---|
| `idle` | `idle` | Ready to configure and start |
| `runningA` | `runningA` | Focus is running or paused |
| `waitingForAConfirm` | `waitingForAConfirm` | Focus complete; waiting for Break confirmation |
| `runningB` | `runningB` | Break is running or paused |
| `endTimestamp` | `endTimestamp` | Absolute deadline while running |
| `paused` | `paused` | Whether the active phase is paused |
| `remainingSeconds` | `remainingSeconds` | Saved time while paused |

The stored configuration uses `durationASeconds` and `durationBSeconds`, matching the Chrome names and defaults.

## Verification

- [x] Xcode project structure validated with `xcodebuild -list`.
- [x] Debug build compiled for the iOS 26.5 Simulator SDK with Xcode 26.5.
- [x] App installed and launched successfully in the iPhone 17 simulator (bundle `com.ebochkarev.FocusTimer`, launch PID reported by `simctl`).
- [x] Initial screen visually verified from a simulator screenshot, including the system notification-permission prompt.
- [ ] Manual Focus → Break flow verified in the simulator.
- [ ] Pause/resume, cancel, persistence, and notifications manually verified.

## Open and run

1. Open `ios/FocusTimer/FocusTimer.xcodeproj` in Xcode 26.5 or later.
2. Select the `FocusTimer` scheme and an iOS 26 iPhone simulator.
3. Press Run.
4. Allow notifications when prompted to exercise completion alerts and the Focus-complete `OK` action.

The project has no package-resolution, code-generation, signing, or setup step for simulator use.

## Intentionally not implemented

The following items are not currently implemented in Chrome and are therefore outside this iPhone parity build:

- Break completion notification buttons for `Done` and `Restart`.
- Restarting Focus from a completion notification.
- A separate `completed` state.
- Custom notification sound assets; the app uses the system default sound.
- Toolbar badge color/tooltip behavior, because that is Chrome-specific.
- Chrome service-worker alarms and heartbeat, because iOS uses persisted deadlines and local notifications instead.
- Chrome's hidden `333`-minute developer shortcut.
- Analytics, network access, account sync, cloud storage, or cross-device synchronization.
- Automated unit, UI, fake-clock, migration, and corrupt-state recovery tests.
- App Store packaging, privacy metadata, screenshots, release automation, and final branding.

## Items from the original specification that remain unimplemented or need fixes

These are copied conceptually from the gaps and future work in `FOCUSTIMER_SPEC.md`; they were deliberately not added to the iPhone project because the request limits this build to already implemented functionality:

- Add `Done` and `Restart` actions to the Break-complete notification.
- Add restart behavior that reuses the last saved durations.
- Add an explicit `completed` state so completion actions remain valid until chosen.
- Add state schema versioning and migrations.
- Add cycle/event versioning to reject stale or duplicate actions.
- Add robust corrupt or partial stored-state recovery.
- Set intentional production defaults and settle decimal-versus-whole-minute duration rules.
- Add custom notification sound only if the product requires one.
- Add comprehensive automated tests, including fake-clock and lifecycle recovery tests.
- Add final app icon/branding and accessibility/contrast QA.
- Add notification-permission guidance when alerts are denied.
- Add packaging, privacy, release, and App Store delivery documentation.
