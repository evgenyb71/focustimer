---
name: end-session
description: End a work session so a new Claude Code or Codex session can continue from the repository alone. Clean up agent-started simulators, bring the phase spec and roadmap up to date, and write a handoff section. No commit, push, merge, or delete without asking.
disable-model-invocation: true
argument-hint: "[optional notes to include in the handoff]"
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git switch:*), Bash(git log:*), Bash(git diff:*), Bash(xcrun simctl list:*), Bash(xcrun simctl shutdown:*), Read, Write, Edit
---

# End Session

Leave the repository in a state another agent (Claude Code or Codex) can continue from without the chat history. The user invokes this explicitly. Update records and write the handoff only: do not commit, push, merge, or delete anything without asking.

## 1. Preflight

1. Read `AGENTS.md`, `specs/ios/roadmap.md`, and the latest phase spec in `specs/ios/phases/` (the one in progress, otherwise the most recently verified). Do not edit `chrome/` or `specs/history/`.
2. Run `git status`, `git branch --show-current`, `git branch`, and `git log --oneline -5`. Note uncommitted changes, local branches, and whether `main` matches `origin/main` (local information only; do not fetch).
3. If uncommitted changes exist that this session did not make, stop and ask: they may belong to another agent. Never discard or overwrite them.

## 2. Clean up the environment

1. Simulators: run `xcrun simctl list devices booted`. Shut down only devices this session booted (`xcrun simctl shutdown <id>`). Leave the user's device running; if unsure which device is whose, ask. Close any simulator panel this session opened.
2. Build output: report the size of agent output in `/tmp` (for example `/tmp/FocusTimerDerivedData`, `/tmp/FocusTimerTests-*.xcresult`). Do not delete it; deletion needs the user's explicit yes per `AGENTS.md`.
3. Do not change `xcode-select`, Xcode settings, schemes, signing, or simulator contents.

## 3. Bring the records up to date

1. Latest phase spec: make the `Status:` line, plan checkboxes, Results (commands, environment, counts), and remaining limitations match what actually happened. Record user-reported checks as user-reported. Mark verified only with evidence.
2. Roadmap: for each completed-table row that says "pending push", check whether the work is merged into `main` and pushed (`git log`, `git branch -r --contains <commit>` without fetching). If so, replace it with the merge commit on `main` and tick the matching "fill in the pushed commit" item in that phase spec. If not pushed, leave it and mention it in the handoff.
3. Do not edit `CHANGELOG.md`; if unmerged work still needs `$update-changelog` before merging, say so in the handoff.

## 4. Write the handoff section

Add a section `## Handoff for the next session (YYYY-MM-DD)` at the end of the latest phase spec. If that spec already has a handoff section, replace it. Older specs keep theirs as history. Write facts only, distinguishing verified, in progress, and planned. Include each item that applies:

- **State:** phases verified and merged, current phase and its status, `main` commit, other local branches and what they hold, anything uncommitted or unpushed.
- **Next step:** the next phase or task, and how to start it (`$start-phase` / `/start-phase`).
- **Decided in chat:** user decisions from this session not yet recorded in a spec or constitution.
- **Open questions:** decisions the next phase must ask the user about.
- **Known issues:** deferred defects, `withKnownIssue` markers and their owning phases.
- **Test baseline:** the latest executed test count from the result bundle (functions, passed, expected failures).
- **Environment:** Xcode version and `xcode-select` state, which simulator agents use and which one is the user's, and where agent build output lives.
- **Deferred items:** checks or rows postponed to later phases.
- Notes the user passed as `$ARGUMENTS`, if any.

## 5. Branch

Never write on `main`. If the current branch is `main`, create `chore/handoff-YYYY-MM-DD` before editing. If a phase branch is in progress, write on it. If on another branch, ask before switching or reusing it.

## 6. Finish

1. Run `git diff --check` and confirm new relative links resolve.
2. Report what was cleaned up, which files changed, where the handoff section is, and what is uncommitted or unpushed.
3. Ask whether to commit, merge into `main` with `--no-ff`, and push. Do these only on the user's explicit request.
4. For any branch or file deletion, show the exact command and what it affects, and wait for a separate explicit yes.
