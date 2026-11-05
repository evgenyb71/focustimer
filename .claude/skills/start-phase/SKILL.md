---
name: start-phase
description: Start the next iOS roadmap phase. Agree the open decisions with the user, create the branch, and write a short phase spec. Spec work only.
disable-model-invocation: true
argument-hint: "[optional phase ID, e.g. I14]"
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git switch:*), Bash(git log:*), Bash(git pull --ff-only:*), Read, Write, Edit, AskUserQuestion
---

# Start Phase

Produce a branch and a phase spec only. Do not implement, build, commit, or push.

## 0. Model check

Before anything else, call `AskUserQuestion`: "This session is running on <model>. Which model should plan this phase?" Options: "Keep <model> (Recommended)", "Switch to another model", and, unless already on Opus, "Switch to Opus". If the user wants to switch, stop and tell them to use the model picker (or `/model`) and run `/start-phase` again.

## 1. Preflight

Run `git status` and `git branch --show-current`. If the tree is dirty or the current branch is not `main`, stop and ask. Then run `git pull --ff-only origin main`, so planning starts from the latest merge; if it fails, stop and ask.

Read `AGENTS.md`, `specs/ios/mission.md`, `specs/ios/tech-stack.md`, and `specs/ios/roadmap.md`.

The phase is `$ARGUMENTS` if given, otherwise the first row in "Next phases". If that phase's spec already exists, offer to continue it; never overwrite it.

## 2. Ask

Call `AskUserQuestion` with only what the documents leave open: scope, design decisions, and which checks the user will run. Put the recommended option first and state the exit check. Nothing is written until the user answers.

## 3. Branch and spec

Run `git switch -c feat/Ixx-short-name`, then write `specs/ios/phases/Ixx-short-name.md`, about one page, with these sections:

- Title, then `Status: planned`.
- **Goal:** the behavior and the roadmap exit check.
- **Decisions:** what the user decided, and any choice worth revisiting.
- **Non-goals.**
- **Plan:** a Markdown checkbox (`- [ ]`) for each implementation step, plus the workflow steps through recording results and the PR. All start unticked.
- **Checks:** agent-run (`scripts/test.sh`, when Swift or project files change) and user-reported Xcode checks, with what stays unverified.
- **Results:** empty until verified. Later it holds the `scripts/test.sh` output, user-reported checks, review findings, and remaining limitations.

Do not restate the invariants or list files.

## 4. Finish

Report the phase, branch, spec path, and open questions. Leave everything uncommitted.
