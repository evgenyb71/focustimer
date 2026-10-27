# Changelog

## 2026-10-27

- Complete a phase when it is paused at or after its deadline, instead of pausing it with one second left: Focus waits for Break confirmation and Break returns to idle. This fixes the known issue owned by I12.
- Handle clock changes: after a backward clock jump, a running timer whose deadline is more than the phase's length away is moved to now plus that length, saved, and its alert rescheduled, with no notice. At launch, a saved paused time longer than the phase is clamped with the correction notice. A forward jump completes the phase on the next check and never skips Break confirmation.
- Add 12 clock-edge tests and fit older test fixtures to their configured durations. Record phase I12 as verified (107 tests on an iPhone 17 Pro simulator, iOS 26.5, all passing with no known issues, with counts from the result bundle; user-reported Cmd+U), and update the iOS mission and tech stack. Known limit: if the saved configuration is unreadable while a longer phase runs, the cap shortens that phase to the default length.
- Fix a review finding on I12: a saved deadline far outside the normal range (for example 1e20 seconds) crashed the app at launch, because the countdown was computed before the timer was reconciled. Launch now reconciles first, capping or completing such a deadline, and the conversions from seconds to whole numbers are bounded. Add launch regressions for extreme future and past deadlines, which crash without the fix, and record the Codex review and its resolution in the I12 spec (109 tests, all passing; user-reported Cmd+U).
- Move I12 to the roadmap's completed table with its merge commit, and record the Codex review approval in the I12 spec.
- Give the two phase ends their own look: when Focus ends, the status card turns amber with a cup symbol, "Focus complete", and a Start Break button, and the duration panel dims; when Break ends, it turns green with a checkmark, "Cycle complete", and a Start Focus button. The time is hidden at both ends, and VoiceOver reads the headline and next step together. Until the completed state arrives (I13), the Break-end screen is unsaved and clears on Start, Cancel, a duration change, or relaunch.
- Add 12 end-state tests. Record phase I24, planned before I13 by user decision, as verified (121 tests on an iPhone 17 Pro simulator, iOS 26.5, all passing, with counts from the result bundle; agent screenshots of both ends; user-reported Cmd+U and a full-cycle check on the user's simulator), keep the I13 decisions made while its planning was paused in the I24 spec, and update the iOS mission and tech stack.
- Move I24 to the roadmap's completed table with its merge commit, and record the Codex review approval in the I24 spec.
- Add a saved completed state after Break: a finished Break now enters `completed`, which keeps the cycle ID, has no deadline, survives relaunch, and shows the "Cycle complete" screen in place of the I24 flag. Until Done and Restart exist, Start Focus begins a new cycle and Cancel returns to idle; durations can be changed while completed, and the delivered Break alert stays until the user leaves completed.
- Move saved data to schema version 3 with an upgrade step that changes no records, so builds before I13 leave data containing `completed` alone. Repair removes stray timing fields from a saved completed state, adds a missing cycle ID, and treats a paused Break with no time left as completed instead of idle.
- Add 15 completed-state tests and update earlier tests that expected idle after Break, including an I09 test that had used "completed" as its unknown-phase example. Record phase I13 as verified (135 tests on an iPhone 17 Pro simulator, iOS 26.5, all passing, with counts from the result bundle; user-reported Cmd+U and an upgrade and relaunch check on the user's simulator), and update the iOS mission, tech stack, and I24 spec.

## 2026-10-26

- Give each Focus → Break cycle a saved cycle ID: it is created when Focus starts, kept while waiting for confirmation and during Break, and removed when Break completes or on Cancel. Completion notifications carry it, and the Focus notification's OK starts Break only when its ID matches the current cycle; an OK from an earlier cycle, without an ID, or repeated after Break started changes nothing.
- Move saved data to schema version 2: a saved cycle in progress gets a cycle ID and keeps its timer, with no notice. Repair adds a missing ID to an active timer (with the correction notice) and removes one from idle.
- Add 16 cycle tests. Record phase I10 as verified (80 tests on an iPhone 17 Pro simulator, iOS 26.5, with counts from the result bundle; user-reported Cmd+U and an upgrade check of version 1 data on the user's simulator), with the manual stale-alert check deferred as a ToDo, and update the iOS mission and tech stack.
- Make the `start-phase` skill ask first which model should plan the phase, and stop so the user can switch models if they choose another.
- Move I10 to the roadmap's completed table with its merge commit, and add a session handoff to the I10 phase spec (next phase I11 and its open questions, known issues, test baseline, environment, and deferred checks).
- Remove notifications that no longer match the timer: starting Break removes the delivered Focus alert, Cancel and a new Focus remove all delivered alerts, Break completion cancels the pending Break request, and launch or returning to the app keeps the Focus alert only while waiting for Break and the Break alert only while Break runs.
- Fix a crash when tapping a notification's OK: the notification delegate finished off the main thread, which UIKit rejects. The bug existed since the app was added and surfaced in the first real tap on an alert; the delegate now runs on the main actor.
- Add 14 alert cleanup tests. Record phase I11 as verified (94 tests on an iPhone 17 Pro simulator, iOS 26.5, with counts from the result bundle; user-reported Cmd+U and a Notification Center check on the user's simulator after the crash fix), with the defect recorded in the I11 spec, and mark the I10 stale-alert ToDo as superseded by that check.
- Fix a review finding on I11: starting a new Focus now also cancels pending alerts, so a Break alert still scheduled when launch ignored an unsupported saved version can no longer go off during the new Focus. Add a regression test with a test scheduler that tracks pending requests, and record the Codex review and its resolution in the I11 spec (95 tests, 94 passed, 1 expected failure; user-reported Cmd+U).
- Move I11 to the roadmap's completed table with its merge commit, note that the I10 stale-alert check was superseded by I11's check, and add a session handoff to the I11 phase spec (next phase I12 and its open questions, known issues, test baseline, testing notes, environment, and deferred checks).

## 2026-10-24

- Recover unreadable saved records at launch: a `config` or `state` that is present but cannot be decoded (corrupt data, an unknown phase, wrong-typed values) is replaced with the default durations or an idle timer, the other record is kept, the status line shows "Saved timer data was corrected.", and pending completion alerts are cancelled for a replaced state. A missing record on a fresh install shows no notice.
- Handle a newer, negative, or unreadable `schemaVersion`: launch still uses defaults in memory and writes nothing, now with the correction notice, and the first save afterwards writes both records and the current version, so the next launch reads them instead of ignoring them again.
- Add 9 recovery tests. Record phase I09 as verified (64 tests on an iPhone 17 Pro simulator, iOS 26.5, with counts from the result bundle; user-reported Cmd+U and two seeded relaunch checks on the user's simulator) and update the iOS mission and tech stack.
- Move I09 to the roadmap's completed table with its merge commit, and add a session handoff to the I09 phase spec (next phase I10 and its open questions, known issues, test baseline, environment, and how to seed simulator preferences through `simctl spawn … defaults write`).

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
- Move I07 to the roadmap's completed table with its merge commit, and add a session handoff to the I07 phase spec (next phase I08 and its open questions, known issues, test baseline, environment, and how to seed simulator data for manual checks).
- Version the saved data: a new `schemaVersion` key covers the `config` and `state` records, which keep their format. Records saved before versioning are migrated at launch through an ordered step list, keeping their settings and timer state, and saved as version 1; a fresh install also saves version 1. A newer, negative, or unreadable version loads defaults in memory and writes nothing at launch, leaving recovery to I09.
- Add 7 migration tests, and let the in-memory test store record which keys it writes. Record phase I08 as verified (55 tests on an iPhone 17 Pro simulator, iOS 26.5, with counts from the result bundle; user-reported Cmd+U and an upgrade check of real pre-I08 data on the user's simulator) and update the iOS mission and tech stack.
- Move I08 to the roadmap's completed table with its merge commit.

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
