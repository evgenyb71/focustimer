---
name: start-phase
description: Start an iOS roadmap phase that is ready and not taken by another agent. Pick it, interview the user with AskUserQuestion, create a branch and worktree, and write the phase spec in specs/ios/phases/. Spec work only.
disable-model-invocation: true
argument-hint: "[optional phase ID, e.g. I03]"
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git switch:*), Bash(git log:*), Bash(git worktree list:*), Bash(git worktree add:*), Bash(git show:*), Bash(git for-each-ref:*), Bash(git update-ref refs/claims/:*), Bash(xcrun simctl list:*), Read, Write, Edit, AskUserQuestion
---

# Start Phase

Prepare one small iOS roadmap phase for implementation. The user invokes this explicitly. Produce a branch, its worktree, and a phase spec only: do not implement, build, commit, push, or merge. Other agents may be working on other phases at the same time; follow [Parallel work in AGENTS.md](../../../AGENTS.md#parallel-work).

## 0. Model check

Before reading anything or running any command, call `AskUserQuestion` with one question: "This session is running on <your model name from the system prompt>. Which model should plan this phase?" Options: "Keep <current model> (Recommended)", "Switch to Opus", and "Switch to another model" (the user can also type one). A skill cannot change the model itself.

- If the user keeps the current model, continue to step 1.
- If the user wants a different one, stop. Tell them to switch in the app's model picker (or `/model` in the terminal), then run `/start-phase` again. Read nothing and write nothing in this session.

## 1. Preflight

1. Read `AGENTS.md`, `specs/ios/mission.md`, `specs/ios/tech-stack.md`, and `specs/ios/roadmap.md` (including "Running phases in parallel"). Do not edit `chrome/` or `specs/history/`.
2. Run `git status`, `git branch --show-current`, `git branch -a`, and `git worktree list`. If this checkout is dirty, stop and ask: the changes may belong to another agent.
3. Find the taken phases and claimed simulators:
   - claim refs: `git for-each-ref refs/claims --format='%(refname)'` (`refs/claims/Ixx`, `refs/claims/sim/<UDID>`, `refs/claims/integration`);
   - every `feat/Ixx-*` branch, local or remote (`git branch -a --list '*feat/I*'`), whose phase is not yet in the roadmap's completed table (do not use `--no-merged`: a just-created branch has no commits and counts as merged);
   - every spec in `specs/ios/phases/` whose `Status:` is in progress.

   For each taken phase, map its branch to a worktree with `git worktree list --porcelain` and read its spec from that worktree (`<worktree>/specs/ios/phases/Ixx-*.md`), since new specs are uncommitted. Use `git show <branch>:specs/ios/phases/<file>` only when no worktree has the branch. From the spec, take its final *Touches* list and its simulator. A taken phase with no readable spec is unavailable: treat its *Touches* as unknown and ask the user about it.
4. Choose the phase: `$ARGUMENTS` if given, otherwise the first forward-table phase that is ready (every *Depends on* phase is in the completed table) and not taken.
5. Stop and ask before going on if:
   - the phase is taken: offer to continue it in its worktree instead;
   - it is not ready: name the missing phases and offer the first ready one;
   - its *Touches* share an entry with a taken phase: name the phase and the shared files, and ask whether to start anyway or pick another ready phase.

   Never overwrite an existing phase spec.

## 2. Ask before writing

Call `AskUserQuestion` before creating any branch, worktree, or file. Group the questions into these three topics (1 to 4 questions per call, 2 to 4 options each, recommended option first). Ask only what the roadmap, mission, and tech-stack leave open, and state the phase and its roadmap exit check in the question text.

1. **Scope**: what is in and out, non-goals, and which known limitations from `tech-stack.md` this phase fixes. Confirm the roadmap's *Depends on*, *Touches*, and *Saved format* entries for this phase.
2. **Decisions**: design choices the documents do not settle.
3. **Validation**: which acceptance checks the user will run in Xcode, which the agent can run, which simulator the agent uses (an installed one that the user and taken phases are not using; check `xcrun simctl list devices`), and what stays unverified.

If the answers raise follow-up gaps, ask again. Nothing is written until the user has answered.

## 3. Recheck, claim, and create the worktree

The interview takes time, and another agent may have claimed the phase or the simulator meanwhile. Never write on `main`, and never in a checkout another agent is using.

1. Repeat preflight step 3 now. If the phase became taken, or a newly taken phase overlaps it, stop and ask.
2. Claim the phase: `git update-ref refs/claims/Ixx main ""`. If it fails, another agent holds the claim: stop and ask.
3. Claim the simulator chosen in step 2: `git update-ref refs/claims/sim/<UDID> main ""`. If it fails, offer another installed simulator that has no claim.
4. Create the branch and worktree:
   - If this session already runs in a worktree of its own (the app's worktree) on a fresh branch with no commits of its own, ask whether to create `feat/Ixx-short-name` there from `main` and use it.
   - Otherwise create a worktree with the branch from `main`: `git worktree add -b feat/Ixx-short-name .claude/worktrees/Ixx-short-name main`, and do all further work there.
   - If the current branch is another phase or chore branch, ask before switching or reusing it.
5. Write the phase spec (step 4) right away, so other agents can read the claim's details from the worktree.

If a later step fails after an earlier claim succeeded (the phase claim is taken but the simulator claim or the worktree creation fails), do not continue and do not leave it unreported. Tell the user exactly what is held: the claim refs created (`refs/claims/Ixx`, `refs/claims/sim/<UDID>`), and any branch or worktree that was created. Then offer recovery (another simulator, or retrying the worktree after fixing the cause) or release. Release follows "Releasing claims" in `AGENTS.md`: show the exact `git update-ref -d` commands, and any branch or worktree removal, and run them only after the user's explicit yes.

## 4. Write `specs/ios/phases/Ixx-short-name.md`

One file in the phase's worktree, using relative links to the roadmap, mission, and tech-stack:

- Title and a `Status:` line: `planned`, plus the date, the roadmap entry it implements, the branch, the worktree path, the agent tool (Claude Code), and the agent's simulator (name and UDID).
- **Requirements**: scope, non-goals, decisions from step 2, context, affected components (files under `ios/FocusTimer/FocusTimer/`), *Depends on*, *Touches*, the planned `schemaVersion` if the saved format changes (the version after the one on `main`, final only at merge), and the invariants to preserve: single authoritative timer state, explicit Break confirmation, local persistence, deadline-based recovery. Note any taken phase whose *Touches* overlap this one.
- **Plan**: numbered task groups, each small enough to review on its own, with `- [ ]` items. Split the phase if it does not fit one focused change. End with an integration group that follows the Integration steps in `AGENTS.md`: take the integration claim, merge `main` into the branch and record the tested base, rerun the full tests, run `$update-changelog`, pass the freshness gate before merging, move the row to the roadmap's completed table in a `chore/roadmap-after-Ixx` branch, and release the claims with the user's yes.
- **Validation**: observable acceptance checks, separated into agent-run commands (the `xcodebuild` commands from `AGENTS.md` with this phase's `Ixx` output paths and simulator, only when Swift or project files change), user-reported Xcode checks (opened from this worktree), and what remains unverified. Add a `Results` section left empty until verification: verified only with recorded evidence.

## 5. Finish

Report the phase, branch, worktree path, file path, the claims taken (`refs/claims/Ixx`, `refs/claims/sim/<UDID>`), the simulator chosen, any overlap with taken phases, and any open questions. Leave everything uncommitted; the claim refs are not commits and stay in place. Do not edit the roadmap or `CHANGELOG.md`.
