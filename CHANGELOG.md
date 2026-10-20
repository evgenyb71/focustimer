# Changelog

## 2026-10-20

- Inject a `Clock` into `TimerStore` so every current-time read goes through one source; production uses `SystemClock`, and the initializer is now internal for future tests.
- Inject one `KeyValueStore` into `TimerStore` and use it for every read and write, fixing saves that ignored the supplied store and always wrote to `UserDefaults.standard`; keys and encoding are unchanged.
- Record combined phase I03-I04 as verified with agent-run build, static checks, and iPhone 17 Pro simulator checks (iOS 26.5), including saved state surviving the update; update the iOS tech stack and merge the I03 and I04 roadmap rows into the completed table.
- Inject a `NotificationScheduling` boundary into `TimerStore`; the production scheduler keeps the same notification content and identifiers but now computes its trigger interval from the injected clock instead of the live clock.
- Add the `FocusTimerTests` unit-test target (Swift Testing, hosted by the app, iOS 26.0, Swift 6) with a fake clock, in-memory store, and recording notification scheduler, and six tests covering schedule and cancel calls, Break scheduled only after confirmation, and writes to the injected store.
- Document the `xcodebuild test` command in `AGENTS.md` and the iOS tech stack, with the rule to confirm the executed test count from the result bundle; unit tests use Swift Testing and XCTest is reserved for UI tests.
- Record phase I05 as verified (agent-run tests on an iPhone 17 Pro simulator, iOS 26.5, user-reported Cmd+U, and an agent simulator flow check) and move it to the roadmap's completed table; record the I03-I04 merge commit in the roadmap.
- Add deterministic `TimerStore` tests for Focus and Break, explicit Break confirmation, pause and resume, cancel from every active state, delayed reconciliation, relaunch from the saved store, the notification OK path, and the displayed countdown; pausing at or after expiry, which adds a second instead of completing, is recorded as a known issue for I12.
- Record phase I06 as verified (36 tests on an iPhone 17 Pro simulator, iOS 26.5, with counts from the result bundle, plus user-reported Cmd+U; no app code changed) and move it to the roadmap's completed table.
- Add a manual-only `end-session` project skill that shuts down agent-started simulators, brings the latest phase spec and roadmap up to date, and writes a handoff section so a new Claude Code or Codex session can continue from the repository; reference it from `AGENTS.md` and `CLAUDE.md`.
- Add the first session handoff to the I06 phase spec (next phase I07 and its open decisions, known issues, test baseline, environment) and record the I06 merge commit in the roadmap.
- Enforce duration bounds in `TimerStore`: saved and started durations are rounded to whole minutes and clamped to Focus 1–240 min and Break 1–120 min, replacing the one-second minimum check; the duration steppers read the same shared ranges.
- Repair saved timer state that breaks the invariants at launch: fields that do not belong to the phase are removed, a running phase without a deadline becomes idle, and a paused phase without positive remaining time is treated as expired (Focus waits for Break confirmation, Break returns to idle). Repairs are saved, obsolete pending alerts are cancelled, and the status line shows "Saved timer data was corrected." until the next action.
- Add 12 invariant tests and raise the transition-test Break duration to the new one-minute minimum. Record phase I07 as verified (48 tests on an iPhone 17 Pro simulator, iOS 26.5, with counts from the result bundle; user-reported Cmd+U and a simulator check of the correction message) and update the iOS mission and tech stack.

## 2026-10-19

- Add a manual-only `start-phase` project skill that picks the next unverified iOS roadmap phase, asks about scope, decisions, and validation, then creates the branch and phase spec; reference it from `AGENTS.md` and `CLAUDE.md`.
- Record phase I01: the Xcode 27.0 simulator build succeeded and the user reported the Focus → confirmation → Break core flow validated on an iPhone 18 Pro Max simulator (iOS 27); notification appearance remains unverified.
- Add roadmap phases I22 to I24 for the launch-state policy, a clearer active-timer indicator, and distinct Focus-end and Break-end states.
- Move verified roadmap phases into a completed table with date, phase spec link, and pushed commit.
- Require agents to ask for explicit confirmation before any remove or delete command.
- Record phase I02: pause/resume, cancel, and relaunch checks passed on the simulator (user-reported, plus agent-run relaunch checks on an iPhone 17 Pro, iOS 26.5) with no defects found; suspension, notification, and remaining relaunch rows are deferred and unverified. Add the I02 phase spec and move I02 to the roadmap's completed table, and note in I22 that relaunching mid-timer should restore the phase and correct time remaining.

## 2026-10-16

- Establish separate Chrome retrospective and iOS constitutions covering mission, tech stack, and small roadmap phases.
- Adopt a spec driven working agreement and refresh the root README; preserve the four original documents unchanged in `specs/history/`.
- Document an Xcode-first verification workflow and safe command-line toolchain checks in the repository guidelines.
- Add `CLAUDE.md` for Claude Code and a manual-only `update-changelog` project skill.
- Extend `.gitignore` for macOS, Xcode user data, Chrome signing keys and packages, editor, and local agent files; stop tracking the stray `.gitx_test` file.
- Move multi-agent handoff and branch/commit rules from `CLAUDE.md` into `AGENTS.md` so every agent follows them, and define when agents should run a command-line build.
- Trim `CLAUDE.md` to Claude-specific guidance, replacing dated status and duplicated code facts with pointers to the iOS roadmap and tech stack.
- Define the commit range the `update-changelog` skill inspects when run on the target branch.
- Share the FocusTimer Xcode scheme so command-line builds no longer depend on an auto-generated scheme.
- Drop redundant `.gitx_test` and `*.xcuserdatad/` ignore rules.

## 2026-10-15

- Document the manual pre-merge changelog workflow in the repository guidelines.
- Configure the iPhone app's development team for automatic signing.
- Ignore local environment configuration, Xcode build output, and signing credentials while retaining environment example files.

## 2026-07-10

- Document the Chrome extension behavior and iPhone app requirements.
- Add the iPhone FocusTimer app with configurable Focus and Break durations, break confirmation, pause/resume, reset, persistent state, and local notifications; replace the temporary iOS project and saved sources.

## 2025-12-26

- Add Xcode project scaffolding and app assets for the iOS app.
- Fix timer phase Codable conformance, track the Xcode workspace, and ignore user-specific Xcode data.

## 2025-12-25

- Add the Chrome FocusTimer extension with a two-phase Focus/Break flow, pause/resume, reset, notifications, badge status, and persistent timer state.
- Add the initial SwiftUI two-phase timer implementation and iOS setup documentation.
