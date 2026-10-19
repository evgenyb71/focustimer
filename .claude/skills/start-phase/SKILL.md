---
name: start-phase
description: Start the next iOS roadmap phase. Pick it, interview the user with AskUserQuestion, create a branch, and write the phase spec in specs/ios/phases/. Spec work only.
disable-model-invocation: true
argument-hint: "[optional phase ID, e.g. I03]"
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git switch:*), Bash(git log:*), Read, Write, Edit, AskUserQuestion
---

# Start Phase

Prepare one small iOS roadmap phase for implementation. The user invokes this explicitly. Produce a branch and a phase spec only: do not implement, build, commit, push, or merge.

## 1. Preflight

1. Read `AGENTS.md`, `specs/ios/mission.md`, `specs/ios/tech-stack.md`, and `specs/ios/roadmap.md`. Do not edit `chrome/` or `specs/history/`.
2. Run `git status` and `git branch --show-current`. If the tree is dirty, stop and ask: the changes may belong to another agent.
3. Choose the phase: `$ARGUMENTS` if given, otherwise the first roadmap phase (I01, I02, ...) with no phase spec in `specs/ios/phases/` or whose spec is not marked verified. Status lives in the phase spec, not the roadmap table.
4. If that phase already has a spec marked in progress, or an earlier phase is unfinished, report it and ask whether to continue it instead. Never overwrite an existing phase spec.

## 2. Ask before writing

Call `AskUserQuestion` before creating any branch or file. Group the questions into these three topics (1 to 4 questions per call, 2 to 4 options each, recommended option first). Ask only what the roadmap, mission, and tech-stack leave open, and state the phase and its roadmap exit check in the question text.

1. **Scope**: what is in and out, non-goals, and which known limitations from `tech-stack.md` this phase fixes.
2. **Decisions**: design choices the documents do not settle.
3. **Validation**: which acceptance checks the user will run in Xcode, which the agent can run, and what stays unverified.

If the answers raise follow-up gaps, ask again. Nothing is written until the user has answered.

## 3. Branch

Create `feat/Ixx-short-name` from the current branch if it is `main`. If on another branch, ask before switching or reusing it. Never write on `main`.

## 4. Write `specs/ios/phases/Ixx-short-name.md`

One file, using relative links to the roadmap, mission, and tech-stack:

- Title and a `Status:` line: `planned`, plus the date and the roadmap entry it implements.
- **Requirements**: scope, non-goals, decisions from step 2, context, affected components (files under `ios/FocusTimer/FocusTimer/`), and the invariants to preserve: single authoritative timer state, explicit Break confirmation, local persistence, deadline-based recovery.
- **Plan**: numbered task groups, each small enough to review on its own, with `- [ ]` items. Split the phase if it does not fit one focused change.
- **Validation**: observable acceptance checks, separated into agent-run commands (exact `xcodebuild` command from `AGENTS.md`, only when Swift or project files change), user-reported Xcode checks, and what remains unverified. Add a `Results` section left empty until verification: verified only with recorded evidence.

## 5. Finish

Report the phase, branch, file path, and any open questions. Leave everything uncommitted. Do not edit the roadmap or `CHANGELOG.md`.
