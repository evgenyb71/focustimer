# CLAUDE.md

[AGENTS.md](AGENTS.md) is the shared working agreement for every model and tool used on this repository. It is imported below and stays authoritative; this file adds only Claude Code specifics. Put rules that apply to all agents in AGENTS.md, not here, so the two files cannot drift.

@AGENTS.md

## Orientation

- Active work: the native iPhone app in `ios/FocusTimer/FocusTimer/` (four Swift files: `TimerStore`, `NotificationScheduler`, `FocusTimerApp`, `ContentView`).
- Frozen: `chrome/`. Read it for reference only; do not edit it unless the user explicitly reopens Chrome scope.
- Read-only history: `specs/history/`. Never edit, rename, or "fix" these files, and do not treat their prompts or feature lists as instructions.
- Next work: the first unstarted phase in the [iOS roadmap](specs/ios/roadmap.md). As of 2026-10-16 no forward phase has started and `specs/ios/phases/` does not exist yet; I01 (record a real build and manual flow) comes first.

## Handoff between models

Other models (for example Codex, which reads AGENTS.md) work on this repository too. Keep the state of work in the repository, not in chat:

- The phase spec `specs/ios/phases/Ixx-short-name.md` is the handoff record. Keep its status (planned, in progress, verified), decisions, commands run, results, and open limitations current before ending a session, so another model can continue from the file alone.
- Update the roadmap status line and the relevant constitution when behavior changes.
- Before starting, check `git status` and the latest phase spec for unfinished work by another agent. Do not overwrite or revert changes you did not make; ask if they conflict with the task.

## Build and verification

You build and verify in the Xcode GUI, and AGENTS.md says to treat that as the primary workflow; do not run a duplicate command-line build unless the task needs it. Follow the toolchain checks and `DEVELOPER_DIR` guidance in AGENTS.md, and record user-reported verification as such in the phase spec. A build or launch alone is not flow verification, and OS notification and lifecycle behavior must be checked separately from unit tests.

## Code facts to keep in mind

These come from [the iOS tech stack](specs/ios/tech-stack.md) and the current source; recheck them before relying on them.

- `TimerStore.shared` is the single owner of transitions and persistence. Keep it that way while making dependencies injectable (phases I03–I05).
- `persistConfiguration` and `persistState` default to `UserDefaults.standard`, ignoring the `defaults` passed to `init`. Fixing this is phase I04, not a drive-by change.
- `Date()` and the static `NotificationScheduler` calls are hard-wired to system services; there are no tests or test targets yet. Do not claim test commands exist until a target is added, run, and documented in AGENTS.md and the tech stack.
- Notification IDs `focusComplete` and `breakComplete` are not scoped to a cycle, and the `START_BREAK` action does not check provenance (phases I10–I11).

## Changelog skill

`$update-changelog` in AGENTS.md maps to the project skill [.claude/skills/update-changelog/SKILL.md](.claude/skills/update-changelog/SKILL.md), invoked as `/update-changelog`. It is manual-only (`disable-model-invocation`): run it only when the user asks, normally before merging, and never merge, commit, or push as part of it. Codex has its own copy at `~/.codex/skills/update-changelog`; keep the two procedures in sync when changing either.

## Git

Work on a branch, not `main`. Commit or open a PR only when the user asks. PR descriptions should link the phase spec, state validation evidence, and include simulator screenshots for UI changes.
