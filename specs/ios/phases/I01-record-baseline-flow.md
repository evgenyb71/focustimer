# I01 Record baseline build and core flow

Status: verified (2026-10-19), user-reported core flow plus agent build. Notification appearance was not reported; see limitations. Implements roadmap phase I01 in the [iOS roadmap](../roadmap.md).

Context: [mission](../mission.md), [tech stack](../tech-stack.md).

## Requirements

### Scope

- Record an actual build of the current app and a manual run of the core flow: idle → Focus running → Focus expiry → explicit Break confirmation → Break running → Break expiry → idle.
- Save the actual environment (simulator or device, iOS version, Xcode version), the result of each step, and any failures. Do not assume the archived I-R03 simulator check covers this flow.

### Non-goals

- Pause/resume, cancel, relaunch, suspension, and notification permission/actions beyond what the core flow touches (phase I02).
- Clock/persistence/notification injection, tests, and any refactor (I03 onward).
- Physical-device checks; chrome/ changes.

### Decisions

- Results are recorded in this file's Results section. User-run Xcode checks are recorded as user-reported; agent-run commands are recorded separately.
- A failure that blocks the core flow may be fixed inside this phase, but only as the smallest change that unblocks it. Fixes are listed as defects with the commit and re-run evidence. Non-blocking defects are logged, not fixed.
- Code changes are expected to be none; if the flow passes, this phase is documentation only.

### Affected components

Read-only unless a blocking defect is fixed: `ios/FocusTimer/FocusTimer/TimerStore.swift`, `NotificationScheduler.swift`, `FocusTimerApp.swift`, `ContentView.swift`.

### Invariants to preserve

Single authoritative timer state, explicit Break confirmation, local persistence, deadline-based recovery. Any blocking fix must not weaken these.

## Plan

1. Agent build evidence
   - [x] Check the toolchain (`xcode-select -p`, `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list`); use `DEVELOPER_DIR=/Applications/Xcode.app` if needed.
   - [x] Run the documented simulator build and record the result under Results.
2. User-run core flow
   - [x] User runs the flow below in Xcode on an iOS 26+ iPhone simulator and reports the environment and outcomes.
   - [x] Record the report under Results as user-reported.
3. Defects and close-out
   - [x] List failures; fix only flow-blocking ones, re-run the affected check.
   - [x] Set status to verified only with the evidence above; update the [roadmap](../roadmap.md) status line and run `/update-changelog` before merging.

## Validation

### Agent-run

Only the build (no tests exist):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FocusTimerDerivedData CODE_SIGNING_ALLOWED=NO build
```

Expected: build succeeds. A build alone does not verify runtime behavior.

### User-reported (Xcode, simulator, default one-minute durations)

1. Launch shows idle with Focus and Break at 1 minute.
2. Start: Focus countdown runs and decreases once per second.
3. At expiry the app shows waiting-for-confirmation; Break does not start by itself.
4. Start Break: Break countdown runs.
5. At Break expiry the app returns to idle with configuration retained.
6. Note whether a completion notification appeared at each expiry (permission granted), and any visual or state errors.

### Unverified after this phase

Pause/resume, cancel, relaunch, suspension, notification actions and denied permission (I02); physical device; accessibility.

## Results

### Agent build (agent-run, 2026-10-19)

- Toolchain: `xcode-select -p` points to `/Applications/Xcode.app/Contents/Developer`; Xcode 27.0 (27A266a); only the iOS 27.0 simulator SDK is installed. This differs from the Xcode 26.5 / iOS 26 SDK baseline in the [tech stack](../tech-stack.md).
- Command: the build command in Validation, with the `DEVELOPER_DIR` prefix and derived data in `/tmp/FocusTimerDerivedData`.
- Result: `** BUILD SUCCEEDED **`. Only the tail of the output was reviewed, so warnings were not inspected.
- Not established: runtime behavior. Installed simulator runtimes include iOS 26.5 (for example iPhone 17 Pro) and iOS 18.3.

### User-reported flow (2026-10-19)

- Environment: iPhone 18 Pro Max simulator, iOS 27; Xcode 27.0 (27A266a). This is the iOS 27 SDK, not the iOS 26.5 runtime planned in the Validation section; the 26.0 minimum deployment target is therefore untested here.
- Result: the user reports the core flow validated (idle → Focus → confirmation → Break → idle). Per-step outcomes for checks 1 to 6 were not itemized.
- Defects: none blocking; no code changed in this phase.
- Observations (not defects against the I01 exit check):
  - The app reopened in the "start Break" (waiting-for-confirmation) state. This is persisted-state recovery as designed in the [mission](../mission.md); whether to keep or reset state across launches is a product question, tracked as roadmap phase I22.
  - It is hard to see which timer (Focus or Break) is active (roadmap I23).
  - The end of Focus and of Break is not clearly shown (roadmap I24).

### Remaining limitations

- Whether completion notifications appeared at each expiry was not reported; notification behavior stays with I02.
- Not run on iOS 26.x or a physical device.
