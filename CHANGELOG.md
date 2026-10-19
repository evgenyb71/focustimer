# Changelog

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
