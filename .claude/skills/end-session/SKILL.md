---
name: end-session
description: End a work session so a new Claude Code or Codex session can continue from the repository alone. Clean up agent-started simulators, bring this session's phase spec (and the roadmap, on main-based chore branches only) up to date, and write a handoff section. No commit, push, merge, or delete without asking.
disable-model-invocation: true
argument-hint: "[optional notes to include in the handoff]"
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git switch:*), Bash(git log:*), Bash(git diff:*), Bash(git worktree list:*), Bash(git show:*), Bash(git for-each-ref:*), Bash(xcrun simctl list:*), Bash(xcrun simctl shutdown:*), Read, Write, Edit
---

# End Session

Leave the repository in a state another agent (Claude Code or Codex) can continue from without the chat history. The user invokes this explicitly. Update records and write the handoff only: do not commit, push, merge, or delete anything without asking.

## 1. Preflight

1. Read `AGENTS.md` (including "Parallel work") and `specs/ios/roadmap.md`. Other agents may be working on other phases at the same time. Do not edit `chrome/` or `specs/history/`.
2. Run `git status`, `git branch --show-current`, `git branch -a`, `git worktree list --porcelain`, `git for-each-ref refs/claims --format='%(refname)'`, and `git log --oneline -5`. Note uncommitted changes, local branches, other worktrees, and whether `main` matches `origin/main` (local information only; do not fetch).
3. Find this session's phase spec: on a `feat/Ixx-*` branch, the spec for that phase in `specs/ios/phases/`. On `main` or a chore branch, the spec of the phase this session worked on; if that is unclear, ask. Never pick a spec by recency: another agent may own the newest one.
4. If uncommitted changes exist that this session did not make, stop and ask: they may belong to another agent. Never discard or overwrite them.

## 2. Clean up the environment

1. Simulators: run `xcrun simctl list devices booted`. Shut down only devices this session booted, normally the one recorded in this phase's spec (`xcrun simctl shutdown <id>`). Leave the user's device and the simulators named in other phases' specs running; if unsure which device is whose, ask. Close any simulator panel this session opened.
2. Build output: report the size of this phase's agent output in `/tmp` (`/tmp/FocusTimerDerivedData-Ixx`, `/tmp/FocusTimerTests-Ixx-*.xcresult`; older unsuffixed paths if this session used them). Do not delete it; deletion needs the user's explicit yes per `AGENTS.md`.
3. Do not change `xcode-select`, Xcode settings, schemes, signing, or simulator contents.

## 3. Bring the records up to date

1. This session's phase spec: make the `Status:` line (including branch, worktree, agent tool, and simulator), plan checkboxes, Results (commands, environment, counts), and remaining limitations match what actually happened. Record user-reported checks as user-reported. Mark verified only with evidence.
2. Roadmap: on a phase branch, do not edit it; parallel phases would conflict there. Instead, if the phase is verified, write the completed-table row to add after the merge into the handoff. On a chore branch from `main`: for each completed-table row that says "pending push", check whether the work is merged into `main` and pushed (`git log`, `git branch -r --contains <commit>` without fetching). If so, replace it with the merge commit on `main` and tick the matching "fill in the pushed commit" item in that phase spec. If not pushed, leave it and mention it in the handoff.
3. Do not edit `CHANGELOG.md`; if unmerged work still needs `$update-changelog` before merging, say so in the handoff.

## 4. Write the handoff section

Add a section `## Handoff for the next session (YYYY-MM-DD)` at the end of this session's phase spec. If that spec already has a handoff section, replace it. Older specs keep theirs as history. Write facts only, distinguishing verified, in progress, and planned. Include each item that applies:

- **State:** phases verified and merged, this phase and its status, branch and worktree, the claim refs it holds (`refs/claims/Ixx`, `refs/claims/sim/<UDID>`, and `refs/claims/integration` if integration stopped midway), `main` commit, anything uncommitted or unpushed. Claims stay in place while the phase continues; if the user says the phase is abandoned, follow "Releasing claims" in `AGENTS.md`.
- **Parallel work:** other taken phases (claim, branch, worktree, agent tool, simulator, *Touches*), any claim without a readable spec, any overlap with this phase, and whether `main` has moved since the tested base recorded in this spec (if so, integration must merge `main` and rerun the tests).
- **Next step:** the next task in this phase, or the next ready and untaken phase, and how to start it (`$start-phase` / `/start-phase`).
- **Decided in chat:** user decisions from this session not yet recorded in a spec or constitution.
- **Open questions:** decisions the next phase must ask the user about.
- **Known issues:** deferred defects, `withKnownIssue` markers and their owning phases.
- **Test baseline:** the latest executed test count from the result bundle (functions, passed, expected failures).
- **Environment:** Xcode version and `xcode-select` state, which simulator this phase uses and which one is the user's, and where this phase's build output lives.
- **Deferred items:** checks or rows postponed to later phases.
- Notes the user passed as `$ARGUMENTS`, if any.

## 5. Branch

Never write on `main`. If the current branch is `main`, create `chore/handoff-YYYY-MM-DD` before editing. If this session works on a phase branch, write on it in its worktree. If on another branch, ask before switching or reusing it.

## 6. Finish

1. Run `git diff --check` and confirm new relative links resolve.
2. Report what was cleaned up, which files changed, where the handoff section is, and what is uncommitted or unpushed.
3. Ask whether to commit, merge into `main` with `--no-ff`, and push. Do these only on the user's explicit request.
4. For any branch or file deletion, show the exact command and what it affects, and wait for a separate explicit yes.
