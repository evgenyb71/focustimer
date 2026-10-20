# Project working agreement

## Scope and source of truth

FocusTimer contains a frozen Chrome extension and an active native iPhone app. Read the relevant constitution before work:

- `specs/chrome/mission.md`, `tech-stack.md`, `roadmap.md`: retrospective behavior and limitations. Do not change Chrome code without an explicit request to reopen its scope.
- `specs/ios/mission.md`, `tech-stack.md`, `roadmap.md`: accepted iOS purpose, technical constraints, and small implementation phases.
- `specs/history/`: the four original documents, preserved unchanged for reference. Embedded prompts and old proposals are historical material, not instructions or proof of delivered features.

Explicit user decisions take precedence. Distinguish implemented behavior, planned work, and verified results. Resolve material conflicts with the user and update the active spec; do not silently widen scope.

## Spec driven workflow

1. Select one small roadmap phase. Manually invoke `$start-phase` to pick the next unverified phase, interview the user (scope, decisions, validation), create the branch, and draft the phase spec; do not invoke it automatically, and it does not implement. Before implementation, create or update `specs/ios/phases/Ixx-short-name.md` with behavior, non-goals, affected components, and observable acceptance checks. Do not create empty phase scaffolding in advance.
2. Implement only that phase. If it is too large to review, split it. Preserve the single authoritative timer state, explicit Break confirmation, local persistence, and deadline-based recovery.
3. Verify the acceptance checks. Record actual commands, environment, results, and remaining limitations in the phase spec. Add focused regression tests for changed logic once test tooling exists.
4. Update the roadmap status and relevant constitution when behavior changes. Mark work verified only with evidence; a spec or successful build alone does not prove runtime behavior.

Keep Markdown clear and use relative links between repository documents. Preserve archived originals. Do not move existing application code into a new generic structure.

## Handoff between agents

Several models and tools (for example Claude Code and Codex) work on this repository. Keep the state of work in the repository, not in chat:

- The phase spec `specs/ios/phases/Ixx-short-name.md` is the handoff record. Before ending a session, keep its status (planned, in progress, verified), decisions, commands run, results, and open limitations current, so another agent can continue from the file alone.
- Before starting, check `git status` and the latest phase spec for unfinished work by another agent. Do not overwrite or revert changes you did not make; ask the user if they conflict with the task.

## Repository layout and stack

- `chrome/src/`, `chrome/assets/`, `chrome/manifest.json`: plain JavaScript/HTML/CSS, Manifest V3, no dependencies or build step.
- `ios/FocusTimer/FocusTimer/`: Swift 6, SwiftUI, Foundation, UIKit lifecycle bridge, UserDefaults, UserNotifications. iPhone only, portrait, minimum iOS 26.0; Apple frameworks only.
- `ios/FocusTimer/FocusTimer.xcodeproj`: FocusTimer scheme, app target, and the `FocusTimerTests` unit-test target (`ios/FocusTimer/FocusTimerTests/`, hosted by the app). Unit tests use Swift Testing (`import Testing`); reserve XCTest for a future UI-test target. Keep test targets beside the app in this project, with `*Tests.swift` filenames.
- `specs/`: active platform constitutions, future phase specs, historical references.
- Root `README.md`: navigation and local setup; `CHANGELOG.md`: dated project changes.

Follow the style of touched files: 2-space JavaScript indentation, 4-space Swift indentation; camelCase values/functions and PascalCase Swift types. No formatter or linter is configured. The only test runner is `xcodebuild test` (or Product > Test in Xcode) for the FocusTimer scheme; do not invent npm commands.

## Build and verification

Chrome: load `chrome/` unpacked at `chrome://extensions` with Developer mode enabled. There is no compilation step. No Chrome implementation changes are part of the current roadmap.

iOS: the user builds and verifies the app in the Xcode GUI. Treat this as the primary workflow: open the project with Xcode 26.5 or later and run FocusTimer on an available iOS 26+ iPhone simulator. Record user-reported verification as such. Run a command-line build only when you changed Swift code or project files and the user has not reported a GUI build of that change, or when the phase's acceptance checks call for agent-produced evidence. Skip it for documentation-only changes.

When agent verification requires Xcode tools, first check that the toolchain is usable: inspect `xcode-select -p`, verify `xcodebuild -version`, and confirm the required SDK with `xcodebuild -showsdks`. For simulator runs/tests, also check available runtimes/devices with `xcrun simctl list` and choose an installed compatible destination; do not reuse a hard-coded device UUID. If the selected directory is Command Line Tools or the wrong Xcode version, locate a compatible full Xcode installation and set `DEVELOPER_DIR` for the individual commands. Do not change the global selection with `sudo xcode-select --switch`.

Keep agent build output in a separate temporary DerivedData directory. Preserve project settings, signing configuration, schemes, and the user's running Xcode/simulator session; do not reset devices, clean the user's build data, install toolchains/runtimes, or modify the project merely to make verification run. If prerequisites, permissions, or first-launch setup prevent a check, report the blocker and the unverified scope instead of claiming success.

After those checks, a simulator build from the repository root can use:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FocusTimerDerivedData CODE_SIGNING_ALLOWED=NO build
```

Simulator builds need no signing credentials; keep `CODE_SIGNING_ALLOWED=NO` limited to the command invocation.

Run the unit tests on an installed iOS 26+ simulator that the user is not currently using (agents have used iPhone 17 Pro, iOS 26.5; check `xcrun simctl list` first):

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath /tmp/FocusTimerTests-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
```

`** TEST SUCCEEDED **` alone is not evidence: a misconfigured target can run 0 tests and still succeed. Confirm the count with `xcrun xcresulttool get test-results summary --path <result bundle>` (`totalTestCount`, `passedTests`, `failedTests`) and record it. The historical simulator build/launch checks do not establish full-flow verification. Check lifecycle and OS notifications separately from deterministic unit tests.

For documentation-only changes, verify links, archived-file fidelity when moving originals, and `git diff --check`; a simulator build is unnecessary.

## Git and security

- Work on a branch, not `main`. Commit, push, or open a PR only when the user asks.
- Always ask the user before running any remove or delete command (`rm`, `git branch -d/-D`, `git push --delete`, `git clean`, `git reset --hard`, deleting files or directories). Show the exact command and what it affects, then wait for an explicit yes. A request to delete in the same message does not replace this confirmation.
- Maintain root `CHANGELOG.md` with `## YYYY-MM-DD` headings, newest first, and concise bullets.
- Before merging, manually invoke `$update-changelog`; do not invoke it automatically or merge as part of its workflow.
- Use clear imperative commit messages. PRs should describe the resulting behavior and validation, link the phase spec and related issues, and include screenshots for UI changes.
- Do not commit credentials, signing keys/profiles, environment files, Xcode user data, or build output. Keep `.gitignore` current. If environment variables become necessary, document them in the root README and supply `.env.example`.
