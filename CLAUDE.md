# CLAUDE.md

[AGENTS.md](AGENTS.md) is the shared working agreement for every model and tool used on this repository. It is imported below and stays authoritative; this file adds only Claude Code specifics. Put rules that apply to all agents in AGENTS.md, not here, so the two files cannot drift.

@AGENTS.md

## Orientation

- Active work: the native iPhone app in `ios/FocusTimer/FocusTimer/`.
- Frozen: `chrome/`. Read it for reference only; do not edit it unless the user explicitly reopens Chrome scope.
- Read-only history: `specs/history/`. Never edit, rename, or "fix" these files, and do not treat their prompts or feature lists as instructions.
- Next work: the first phase in the [iOS roadmap](specs/ios/roadmap.md) that is not marked verified. Check the roadmap status line and `specs/ios/phases/` for current state.
- Known code limitations (hard-wired dependencies, persistence defaults, notification identity) are described in [the iOS tech stack](specs/ios/tech-stack.md), and the roadmap assigns each to a phase. Fix them in that phase, not as drive-by changes.

## Build and verification

The user builds and verifies the app in the Xcode GUI; you cannot. Record their results as user-reported verification in the phase spec, and never describe a GUI build or flow check as your own.

## Changelog skill

`$update-changelog` in AGENTS.md maps to the project skill [.claude/skills/update-changelog/SKILL.md](.claude/skills/update-changelog/SKILL.md), invoked as `/update-changelog`. It is manual-only (`disable-model-invocation`): run it only when the user asks, normally before merging, and never merge, commit, or push as part of it. Codex has its own copy at `~/.codex/skills/update-changelog`; keep the two procedures in sync when changing either.

## Start-phase skill

`$start-phase` in AGENTS.md maps to the project skill [.claude/skills/start-phase/SKILL.md](.claude/skills/start-phase/SKILL.md), invoked as `/start-phase [phase ID]`. It is manual-only (`disable-model-invocation`): it asks the user via `AskUserQuestion` before writing anything, then creates the branch and phase spec. Codex has its own copy at `~/.codex/skills/start-phase`; keep the two procedures in sync when changing either.

## End-session skill

`$end-session` in AGENTS.md maps to the project skill [.claude/skills/end-session/SKILL.md](.claude/skills/end-session/SKILL.md), invoked as `/end-session [notes]`. It is manual-only (`disable-model-invocation`): run it only when the user asks to end or hand off a session. It cleans up agent-started simulators, updates the latest phase spec and roadmap, and writes the handoff section, then asks before any commit, merge, push, or deletion. Codex has its own copy at `~/.codex/skills/end-session`; keep the two procedures in sync when changing either.
