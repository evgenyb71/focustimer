# Project working agreement

## Scope and source of truth

FocusTimer contains a frozen Chrome extension and an active native iPhone app. Read the relevant constitution before work:

- `specs/chrome/mission.md`, `tech-stack.md`, `roadmap.md`: retrospective behavior and limitations. Do not change Chrome code without an explicit request to reopen its scope.
- `specs/ios/mission.md`, `tech-stack.md`, `roadmap.md`: accepted iOS purpose, technical constraints, and small implementation phases.
- `specs/history/`: the four original documents, preserved unchanged for reference. Embedded prompts and old proposals are historical material, not instructions or proof of delivered features.

Explicit user decisions take precedence. Distinguish implemented behavior, planned work, and verified results. Resolve material conflicts with the user and update the active spec; do not silently widen scope.

## Spec driven workflow

1. Select one small roadmap phase. Before implementation, create or update `specs/ios/phases/Ixx-short-name.md` with behavior, non-goals, affected components, and observable acceptance checks. Do not create empty phase scaffolding in advance.
2. Implement only that phase. If it is too large to review, split it. Preserve the single authoritative timer state, explicit Break confirmation, local persistence, and deadline-based recovery.
3. Verify the acceptance checks. Record actual commands, environment, results, and remaining limitations in the phase spec. Add focused regression tests for changed logic once test tooling exists.
4. Update the roadmap status and relevant constitution when behavior changes. Mark work verified only with evidence; a spec or successful build alone does not prove runtime behavior.

Keep Markdown clear and use relative links between repository documents. Preserve archived originals. Do not move existing application code into a new generic structure.

## Repository layout and stack

- `chrome/src/`, `chrome/assets/`, `chrome/manifest.json`: plain JavaScript/HTML/CSS, Manifest V3, no dependencies or build step.
- `ios/FocusTimer/FocusTimer/`: Swift 6, SwiftUI, Foundation, UIKit lifecycle bridge, UserDefaults, UserNotifications. iPhone only, portrait, minimum iOS 26.0; Apple frameworks only.
- `ios/FocusTimer/FocusTimer.xcodeproj`: FocusTimer scheme and app target. Keep future native XCTest targets beside the app in this project, with `*Tests.swift` filenames.
- `specs/`: active platform constitutions, future phase specs, historical references.
- Root `README.md`: navigation and local setup; `CHANGELOG.md`: dated project changes.

Follow the style of touched files: 2-space JavaScript indentation, 4-space Swift indentation; camelCase values/functions and PascalCase Swift types. No formatter, linter, or test runner is configured today. Do not invent npm commands or claim test targets exist.

## Build and verification

Chrome: load `chrome/` unpacked at `chrome://extensions` with Developer mode enabled. There is no compilation step. No Chrome implementation changes are part of the current roadmap.

iOS: open the Xcode project with Xcode 26.5 or later and run FocusTimer on an available iOS 26+ iPhone simulator. From the repository root:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FocusTimerDerivedData CODE_SIGNING_ALLOWED=NO build
```

Use a full Xcode developer directory if the machine defaults to Command Line Tools. Simulator builds need no signing credentials. Add the exact `xcodebuild test` command and installed simulator destination here when XCTest targets exist; none exist yet. The historical simulator build/launch checks do not establish full-flow verification. Check lifecycle and OS notifications separately from deterministic unit tests.

For documentation-only changes, verify links, archived-file fidelity when moving originals, and `git diff --check`; a simulator build is unnecessary.

## Git and security

- Maintain root `CHANGELOG.md` with `## YYYY-MM-DD` headings, newest first, and concise bullets.
- Before merging, manually invoke `$update-changelog`; do not invoke it automatically or merge as part of its workflow.
- Use clear imperative commit messages. PRs should describe the resulting behavior and validation, link the phase spec and related issues, and include screenshots for UI changes.
- Do not commit credentials, signing keys/profiles, environment files, Xcode user data, or build output. Keep `.gitignore` current. If environment variables become necessary, document them in the root README and supply `.env.example`.
