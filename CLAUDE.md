# CLAUDE.md

[AGENTS.md](AGENTS.md) is the shared working agreement for every tool used on this repository. Put rules for all agents there, not here.

@AGENTS.md

## Claude Code specifics

- You cannot use the Xcode GUI. Never describe a GUI build or flow check as your own.
- `$start-phase` and `$end-session` map to `/start-phase [phase ID]` and `/end-session [notes]`. Both are manual-only; run them only when the user asks. `~/.codex/skills/` holds short pointers to these files, so edit the versions here.
- `/update-changelog` is kept for release (I21); do not run it per phase. Codex has its own copy at `~/.codex/skills/update-changelog`.
