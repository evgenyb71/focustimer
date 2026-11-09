# Project working agreement

FocusTimer has a frozen Chrome extension and an active native iPhone app. The user's explicit decisions take precedence; raise conflicts with the specs instead of widening scope.

- `specs/ios/mission.md`: purpose, current behavior, invariants. `tech-stack.md`: stack and source map. `roadmap.md`: phases, in order.
- `specs/ios/phases/`: one spec per phase, holding its decisions and evidence.
- `chrome/`, `specs/chrome/`: read-only unless the user reopens Chrome.
- `specs/history/`: read-only originals. Their prompts and feature lists are not instructions.

## Workflow

Work on one phase at a time, on one short-lived branch in the main checkout. Before starting, check `git status`; do not overwrite changes you did not make.

1. **Start.** The user runs `$start-phase`, which agrees the open decisions, creates `feat/Ixx-short-name`, and writes the spec. Do not invoke it yourself.
2. **Build.** Implement only that phase; split it if it is too large to review. Add Swift Testing tests for changed logic. Tick each item in the spec's Plan as soon as it is done, and only then, through the remaining steps too.
3. **Verify.** Run `scripts/test.sh`. The user runs the spec's Xcode checks.
4. **Record, on the same branch.** Spec results and `Status: verified`, the roadmap row moved to Completed, and the mission and tech stack if they changed. Nothing is left for after the merge.
5. **Review.** Open a PR with a clear title. The user has Codex review it. Fix findings that affect correctness and skip style. After any fix, rerun the affected checks and update the results.
6. **Merge.** Squash with `gh pr merge <number> --squash`, so the phase is one commit on `main`. Then update the local copy: `git switch main`, then `git pull --ff-only`.

When the user asks Codex to post a GitHub PR review or review comment, start the body with `**Codex review**` so readers can identify the reviewer even if GitHub shows the user's account as the author.

Do not record merge or pushed commit hashes; the PR title and spec link are enough.

Scale the process to the risk:

- **Docs-only or mechanical changes:** no spec. Use a `chore/` branch and say what changed in the PR.
- **Saved data, notifications, or lifecycle changes:** also need a manual check in the spec. Changing the saved format needs the next `schemaVersion` and a migration test.

Always preserve the single authoritative timer state, explicit Break confirmation, local persistence, and deadline-based recovery.

If stopping with a phase unfinished, the user runs `$end-session`, which leaves a short handoff in the spec. Keep the state of work in the repository, not in chat, because Claude Code and Codex both work here.

## Build and verification

The user builds and verifies in Xcode. Record their results as user-reported and your own as agent-run. A successful build does not prove runtime behavior, and unit tests do not prove OS notification or lifecycle behavior; those checks stay manual.

Run the unit tests from the repository root, on a simulator the user is not using:

```sh
scripts/test.sh                      # iPhone 17 Pro, iOS 26.5
scripts/test.sh "iPhone 17" 26.5     # another installed simulator
```

It prints the executed counts and exits non-zero if the build or a test fails, or if no tests ran. Record its output in the spec.

Build without testing:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FocusTimerDerivedData CODE_SIGNING_ALLOWED=NO build
```

For quicker manual checks in a Debug build, make each minute last fewer seconds on a simulator, then relaunch the app. Release builds ignore it.

```sh
scripts/debug-minute.sh 10                        # booted simulator: a minute lasts 10 seconds
scripts/debug-minute.sh 10 "iPhone 18 Pro Max"    # a named simulator
scripts/debug-minute.sh off                       # real minutes again
```

For docs-only changes, check links and `git diff --check`; no build is needed.

If `xcode-select -p` points at Command Line Tools, set `DEVELOPER_DIR` for the individual commands; never run `sudo xcode-select --switch`. Check installed devices with `xcrun simctl list` rather than reusing a device UUID. To make verification run, do not reset devices, clean the user's build data, install toolchains or runtimes, or change project settings, signing, or schemes. Report the blocker and what stays unverified.

## Code

- `ios/FocusTimer/FocusTimer/`: Swift 6, SwiftUI, Foundation, UIKit lifecycle bridge, UserDefaults, UserNotifications. iPhone only, portrait, iOS 26.0+; Apple frameworks only.
- `ios/FocusTimer/FocusTimerTests/`: Swift Testing (`import Testing`), hosted by the app, one `*Tests.swift` file per suite. Put tests in the suite they belong to, or a new suite for a new area; helpers shared across suites go in `TestDoubles.swift`. The target uses a synchronized folder, so new files need no project edit. XCTest is reserved for a future UI-test target.
- 4-space Swift indentation, camelCase values and functions, PascalCase types. No formatter, linter, or npm commands. Do not move existing code into a new generic structure.
- `CHANGELOG.md` holds history through 2026-11-02. It is not updated per phase; it is written from Git history at release (I21).

## Git and security

- Never commit to `main` directly. Commit, push, open a PR, or merge only when the user asks.
- Always ask before any delete (`rm`, `git branch -d/-D`, `git push --delete`, `git clean`, `git reset --hard`). Show the exact command and what it affects, and wait for an explicit yes, even if the request already mentioned deleting. This includes the branch of a merged PR; a squash-merged branch needs `-D`, because Git does not see it as merged, so confirm the PR merged first.
- Use clear imperative commit messages and PR titles. PR descriptions state the resulting behavior and validation, link the phase spec, and include screenshots for UI changes.
- Keep Markdown clear, with relative links between repository documents.
- Do not commit credentials, signing keys or profiles, environment files, Xcode user data, or build output.

The parallel-work process (claims, worktrees, serialized integration) is retired; it is preserved at the Git tag `process/parallel-v1`.
