# Changelog

## 2026-10-16

- Establish separate Chrome retrospective and iOS constitutions covering mission, tech stack, and small roadmap phases.
- Adopt a spec driven working agreement and refresh the root README; preserve the four original documents unchanged in `specs/history/`.
- Document an Xcode-first verification workflow and safe command-line toolchain checks in the repository guidelines.
- Add `CLAUDE.md` for Claude Code and a manual-only `update-changelog` project skill.
- Extend `.gitignore` for macOS, Xcode user data, Chrome signing keys and packages, editor, and local agent files; stop tracking the stray `.gitx_test` file.

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
