# I25 Split the unit tests by area

Status: verified (2026-11-02): 135 tests before and after the split, all passed, identical test identifiers, agent-run on iPhone 17 Pro iOS 26.5; user-reported Cmd+U passed. Commit `896377f` (changelog and spec `e41dd22`) on branch `feat/I25-split-unit-tests`; merged to `main` as `d1f6337` and pushed. Implements roadmap phase I25, "Split the unit tests by area (added for parallel work)". Branch `feat/I25-split-unit-tests`, worktree `.claude/worktrees/I25-split-unit-tests`, agent tool Claude Code, agent simulator iPhone 17 Pro, iOS 26.5 (`0AC7E848-0A25-4AB4-AD98-A987990FB358`). Claims held: `refs/claims/I25`, `refs/claims/sim/0AC7E848-0A25-4AB4-AD98-A987990FB358`.

Context: [roadmap](../roadmap.md) (see "Running phases in parallel"), [mission](../mission.md), [tech stack](../tech-stack.md), [Parallel work in AGENTS.md](../../../AGENTS.md#parallel-work), previous phase [I13](I13-completed-state.md).

Roadmap exit check: `FocusTimerTests.swift` is split into one `*Tests.swift` file per area, with shared helpers in `TestDoubles.swift`; no test logic changes; the executed test count from the result bundle equals the count before the split.

## Requirements

### Scope

All unit tests live in one 2,336-line file, `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift`, which every code phase edits. That makes it the one file that would make parallel phases conflict. This phase moves each test suite into a file of its own, without changing any test, and records a convention so later phases add their tests in new files.

The file holds 10 suites (top-level `struct`s, plus one `extension`) and six file-level enums used as test arguments:

| Suite | Starts at line | Enums it uses |
| --- | --- | --- |
| `TimerStoreNotificationTests` | 6 | — |
| `TimerStoreTransitionTests` (and its `extension`) | 114, 413 | `TimedPhase`, `CancelStart` |
| `TimerStoreInvariantTests` | 601 | `TimedPhase`, `NoticeClearingAction` |
| `TimerStoreMigrationTests` | 846 | `TimedPhase`, `UnversionedState` |
| `TimerStoreRecoveryTests` | 1011 | — |
| `TimerStoreCycleTests` | 1172 | `UnversionedState` |
| `TimerStoreAlertCleanupTests` | 1433 | `CleanupPhase` |
| `TimerStoreClockEdgeTests` | 1680 | `ClockJumpPhase` |
| `TimerStoreEndStateTests` | 1965 | — |
| `TimerStoreCompletedStateTests` | 2102 | — |

Each suite already has its own helpers (`makeTimer`, `seed`, `load`, `savedState`, …). No suite calls another suite's helpers; `TimerStoreRecoveryTests` refers only to its own static members.

### Decisions (user, 2026-11-02)

- **Scope: tests plus the convention docs.** Split the suites, and add the per-phase test-file convention to `AGENTS.md` and the tech stack. *Touches* becomes `Tests, docs` (the roadmap row says `Tests`; the row leaves the forward table at integration, so it is not edited).
- **Shape: one file per suite, shared enums in `TestDoubles.swift`.** Each file is named after its suite (for example `TimerStoreTransitionTests.swift`). `TimedPhase` and `UnversionedState`, used by more than one suite, move to `TestDoubles.swift`. Enums used by one suite move with it. Per-suite helpers stay as they are.
- **Validation: agent before and after, plus user Cmd+U.** The agent runs the full tests on iPhone 17 Pro, iOS 26.5 (not the user's iPhone 18 Pro Max) before and after the split; the user runs Cmd+U in Xcode from this worktree.

### Agent decisions within the user's choices (open to revision)

- **One blank line removed** (found during implementation): the original had two blank lines between `TimerStoreAlertCleanupTests` and the `ClockJumpPhase` enum (line 1674), at a point where the file is split. Each new file uses one blank line between declarations. The other double blank line (line 1889, inside `TimerStoreClockEdgeTests`) is kept verbatim.

- **The original file becomes the first suite's file.** `FocusTimerTests.swift` is renamed with `git mv` to `TimerStoreNotificationTests.swift` and trimmed to that suite. Outcome: only 98 of 2,336 lines remain, so Git records a delete and an add, and `git log --follow` does not link the history; use `git log -- ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift` for the old file. The other suites are cut out into new files. Renaming removes the old file name, so the agent shows the exact `git mv` command and waits for the user's yes before running it.
- **Text moves verbatim.** Each file gets the same three imports (`Foundation`, `Testing`, `@testable import FocusTimer`) and the suite's code unchanged, including its `@MainActor` attribute, `// MARK:` comments, and blank lines. Nothing is renamed or reformatted.
- **Shared enums go after the existing doubles** in `TestDoubles.swift`, under a `// MARK: Shared test arguments` comment, with their current access level and `Sendable`/`CaseIterable` conformances.
- **Convention text** (for `AGENTS.md` repository layout and the tech-stack source map): unit tests are split one file per area, named after the suite; a phase adds its new tests in a new `*Tests.swift` file of its own, edits an existing test file only to update tests its change affects, and puts helpers shared by several files in `TestDoubles.swift`.

### Non-goals

- No change to any test's logic, name, arguments, or expectations.
- No deduplication of the repeated per-suite helpers.
- No change to app code (`ios/FocusTimer/FocusTimer/`) or to the Xcode project file. Both targets use synchronized folders (`PBXFileSystemSynchronizedRootGroup`), so new files are included without project edits; if a build shows otherwise, stop and ask rather than edit the project.
- No split of `TimerStore.swift` or `ContentView.swift`.
- No new tests.

### Affected components

- `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift` → renamed to `TimerStoreNotificationTests.swift`.
- New: nine `ios/FocusTimer/FocusTimerTests/TimerStore*Tests.swift` files, one per remaining suite.
- `ios/FocusTimer/FocusTimerTests/TestDoubles.swift`: gains `TimedPhase` and `UnversionedState`.
- `AGENTS.md` (repository layout) and `specs/ios/tech-stack.md` (source map and test paragraph): the convention and the new file list.
- No files under `ios/FocusTimer/FocusTimer/`.

*Depends on:* none. *Touches:* Tests, docs. *Saved format:* no change.

Overlap with taken phases: none at planning time (no other claims or `feat/I*` branches on 2026-11-02). Every later code phase touches `Tests` and depends on I25.

### Invariants to preserve

Only test files move, so app behavior cannot change. The tests that guard the invariants must all still run and pass: single authoritative timer state, explicit Break confirmation, local persistence, deadline-based recovery.

## Plan

1. Baseline
   - [x] Check the toolchain (`xcode-select -p`, `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list`) and that the claimed simulator is still free.
   - [x] Run the full test command on `main`'s code in this worktree (before any edit) and record the result bundle, `totalTestCount`, `passedTests`, `failedTests`.
   - [x] Export the list of test identifiers from that bundle (`xcrun xcresulttool get test-results tests --path <bundle>`), sorted, to a scratch file.
2. Split
   - [x] With the user's yes, `git mv ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift ios/FocusTimer/FocusTimerTests/TimerStoreNotificationTests.swift`.
   - [x] Cut each other suite, with the enums only it uses, into `TimerStore<Area>Tests.swift` with the three imports; keep the `TimerStoreTransitionTests` extension in that suite's file.
   - [x] Move `TimedPhase` and `UnversionedState` to `TestDoubles.swift`.
   - [x] Check that the moved text is unchanged: the concatenated suite bodies match the original file's suite text, apart from imports and the moved enums (scripted diff, recorded in Results).
3. Verify
   - [x] Run the full test command again; record the bundle and counts. `totalTestCount` equals the baseline, all pass.
   - [x] Export the test identifiers again and `diff` them with the baseline list: no difference.
   - [x] `git diff --stat main...HEAD` shows changes only under `ios/FocusTimer/FocusTimerTests/` and the two docs.
4. Docs
   - [x] Add the convention to `AGENTS.md` (repository layout) and update the tech-stack source map and test paragraph with the new files.
   - [x] `git diff --check`; check relative links.
   - [x] Ask the user for Cmd+U in Xcode, opened from this worktree, and record the reported result.
5. Integration (following the Integration steps in `AGENTS.md`, only when the user asks to merge)
   - [x] Take `refs/claims/integration`.
   - [x] Merge `main` into this branch; record the tested base (`git rev-parse main`).
   - [x] If `main` moved since step 3, rerun the full tests and record the bundle and count.
   - [x] Run `$update-changelog`; commit when the user asks.
   - [x] Freshness gate: in the integration checkout, `git rev-parse main` still equals the tested base, then `git merge --no-ff feat/I25-split-unit-tests`.
   - [x] In `chore/roadmap-after-I25` from `main`: move I25 from the forward table to the completed table (deliverable, date, spec link, pushed commit).
   - [ ] With the user's yes, release `refs/claims/integration`, `refs/claims/I25`, and `refs/claims/sim/0AC7E848-0A25-4AB4-AD98-A987990FB358`.

## Validation

### Agent-run

Toolchain checks first, per `AGENTS.md`. From the worktree root, on the claimed simulator:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData-I25 -resultBundlePath /tmp/FocusTimerTests-I25-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
```

Then, for each bundle:

```sh
xcrun xcresulttool get test-results summary --path <bundle>
xcrun xcresulttool get test-results tests --path <bundle>
```

Acceptance:

- A1: before the split, the baseline run passes; record `totalTestCount` (135 expected from I13).
- A2: after the split, `totalTestCount`, `passedTests` equal A1; `failedTests` 0, `expectedFailures` 0.
- A3: the sorted test identifiers before and after are identical.
- A4: the moved suite text is unchanged (scripted comparison).
- A5: `git diff --stat main...HEAD` lists only `ios/FocusTimer/FocusTimerTests/*`, `AGENTS.md`, `specs/ios/tech-stack.md`, and this spec; no `project.pbxproj` change.
- A6: `git diff --check` is clean and new relative links resolve.

### User-reported (Xcode)

- U1: open `ios/FocusTimer/FocusTimer.xcodeproj` from `.claude/worktrees/I25-split-unit-tests`, Product > Test (Cmd+U). All tests pass, and the Test navigator shows the 10 suites. Record the reported result, with the count if given.

### Remains unverified

- Nothing at runtime changes, so no simulator flow, lifecycle, or notification check applies.
- Physical device: not needed for a test-only change.

## Results

### Agent-run (2026-11-02)

- Toolchain: `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; Xcode 27.2 (27B52); destination iPhone 17 Pro, iOS 26.5 (`0AC7E848-0A25-4AB4-AD98-A987990FB358`, claimed; OS build 23F77). The user's iPhone 18 Pro Max (iOS 27.0) was not used; `simctl` now lists it as unavailable ("runtime profile not found"), and the installed simulator SDK is iOS 27.2.
- A1, baseline before any edit (`/tmp/FocusTimerTests-I25-20261102-195010-before.xcresult`): `** TEST SUCCEEDED **`; `xcresulttool get test-results summary`: result Passed, `totalTestCount` 135, `passedTests` 135, `failedTests` 0, `skippedTests` 0, `expectedFailures` 0. 135 test identifiers exported from `get test-results tests`.
- Split: `git mv` of `FocusTimerTests.swift` to `TimerStoreNotificationTests.swift` (user's yes), then a script cut the other nine suites, with their single-suite enums, into new files and appended `TimedPhase` and `UnversionedState` to `TestDoubles.swift`.
- A4, moved text: the script asserted that the suite segments, joined with one blank line, equal the original body with only the line-1674 blank line removed. An independent check found the multiset of 1,814 non-blank lines identical between the original (without imports) and the new files (without their added imports and the `// MARK: Shared test arguments` comment); `TestDoubles.swift` keeps its original content unchanged as a prefix.
- A2, after the split (`/tmp/FocusTimerTests-I25-20261102-195346-after.xcresult`): `** TEST SUCCEEDED **`; result Passed, `totalTestCount` 135, `passedTests` 135, `failedTests` 0, `skippedTests` 0, `expectedFailures` 0. No compiler errors or Swift warnings in the build output.
- A3: the sorted lists of 135 test identifiers before and after are identical (`diff` shows no difference).
- A5: `git diff --stat main` lists only `ios/FocusTimer/FocusTimerTests/` files, `AGENTS.md`, and `specs/ios/tech-stack.md` (plus the untracked new test files and this spec); no `project.pbxproj` change. Resulting files: `TimerStoreNotificationTests` 98 lines, `…TransitionTests` 490, `…InvariantTests` 247, `…MigrationTests` 168, `…RecoveryTests` 164, `…CycleTests` 260, `…AlertCleanupTests` 249, `…ClockEdgeTests` 292, `…EndStateTests` 140, `…CompletedStateTests` 240, `TestDoubles.swift` 116.
- A6: `git diff --check` clean; relative links in this spec, `AGENTS.md`, and the tech stack resolve.

### Integration (2026-11-02)

- Implementation commit `896377f` on `feat/I25-split-unit-tests`. Integration claim taken; `git merge main` was already up to date. Tested base: `main` at `448f8de`, the commit both test runs used, so no rerun was needed.

- Freshness gate: in the integration checkout `main` was still `448f8de`; merged with `--no-ff` as `d1f6337`. Roadmap row moved in `chore/roadmap-after-I25` (merged as `96e30d4`); pushed to `origin/main` on 2026-11-02, and the roadmap row's pushed commit filled in.

### User-reported

- U1, 2026-11-02, Cmd+U in Xcode 27.2 from this worktree: reported "All passed" by the user. The simulator used and the count were not included. (The iPhone 18 Pro Max used in earlier phases is listed as unavailable with Xcode 27.2.)
