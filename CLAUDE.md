# CLAUDE.md

[AGENTS.md](AGENTS.md) is the shared working agreement for every model and tool used on this repository. It is imported below and stays authoritative; this file adds only Claude Code specifics. Put rules that apply to all agents in AGENTS.md, not here, so the two files cannot drift.

@AGENTS.md

## Orientation

- Active work: the native iPhone app in `ios/FocusTimer/FocusTimer/`.
- Frozen: `chrome/`. Read it for reference only; do not edit it unless the user explicitly reopens Chrome scope.
- Read-only history: `specs/history/`. Never edit, rename, or "fix" these files, and do not treat their prompts or feature lists as instructions.
- Next work: a phase in the [iOS roadmap](specs/ios/roadmap.md) that is ready (its dependencies are in the completed table) and not taken by another agent (no `refs/claims/Ixx` claim and no unfinished `feat/Ixx-*` branch); see [Parallel work](AGENTS.md#parallel-work). Check `git for-each-ref refs/claims`, `git worktree list --porcelain`, and each claimed phase's spec in its worktree.
- Parallel sessions: when the user wants several phases at once, run each in its own session with its own worktree (the app's worktree option, or `.claude/worktrees/`). One session per phase; never two sessions writing in the same checkout.
- Known code limitations (hard-wired dependencies, persistence defaults, notification identity) are described in [the iOS tech stack](specs/ios/tech-stack.md), and the roadmap assigns each to a phase. Fix them in that phase, not as drive-by changes.

## Build and verification

The user builds and verifies the app in the Xcode GUI; you cannot. Record their results as user-reported verification in the phase spec, and never describe a GUI build or flow check as your own.

## Changelog skill

`$update-changelog` in AGENTS.md maps to the project skill [.claude/skills/update-changelog/SKILL.md](.claude/skills/update-changelog/SKILL.md), invoked as `/update-changelog`. It is manual-only (`disable-model-invocation`): run it only when the user asks, normally before merging, and never merge, commit, or push as part of it. Codex has its own copy at `~/.codex/skills/update-changelog`; keep the two procedures in sync when changing either.

## Start-phase skill

`$start-phase` in AGENTS.md maps to the project skill [.claude/skills/start-phase/SKILL.md](.claude/skills/start-phase/SKILL.md), invoked as `/start-phase [phase ID]`. It is manual-only (`disable-model-invocation`): it asks the user via `AskUserQuestion` before writing anything, then creates the branch and phase spec. Codex has its own copy at `~/.codex/skills/start-phase`; keep the two procedures in sync when changing either.

## End-session skill

`$end-session` in AGENTS.md maps to the project skill [.claude/skills/end-session/SKILL.md](.claude/skills/end-session/SKILL.md), invoked as `/end-session [notes]`. It is manual-only (`disable-model-invocation`): run it only when the user asks to end or hand off a session. It cleans up agent-started simulators, updates this session's phase spec (and the roadmap only on `main`-based chore branches), and writes the handoff section, then asks before any commit, merge, push, or deletion. Codex has its own copy at `~/.codex/skills/end-session`; keep the two procedures in sync when changing either.
