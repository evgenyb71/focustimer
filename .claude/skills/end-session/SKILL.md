---
name: end-session
description: Stop work so a new Claude Code or Codex session can continue from the repository. Shut down agent-started simulators and, if a phase is unfinished, write a short handoff in its spec. No commit, push, or delete without asking.
disable-model-invocation: true
argument-hint: "[optional notes for the handoff]"
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git diff:*), Bash(xcrun simctl list:*), Bash(xcrun simctl shutdown:*), Read, Write, Edit
---

# End Session

1. Run `git status`, `git branch --show-current`, and `git log --oneline -3`. If there are changes this session did not make, stop and ask.
2. Shut down only the simulators this session booted (`xcrun simctl list devices booted`, then `xcrun simctl shutdown <id>`). If unsure which device is whose, ask.
3. If a phase is unfinished, update its spec on its branch, and never on `main`: the `Status:` line and Results, then a `## Handoff` section, replacing any earlier one, with what is done, the next step, open questions, what is unverified, and any notes from `$ARGUMENTS`. If nothing is unfinished, change no files and report the next roadmap phase.
4. Report what is uncommitted or unpushed, and ask before any commit or push. For any delete, show the exact command and wait for an explicit yes.
