---
name: update-changelog
description: Manually create or update the repository-root CHANGELOG.md from Git history and current branch changes before merging, with dated headings and concise bullets.
disable-model-invocation: true
---

# Update Changelog

Maintain `CHANGELOG.md` in the repository root. The user invokes this explicitly, usually before merging. Never run it on your own initiative.

## Inspect the changes

1. Read `AGENTS.md`, the existing `CHANGELOG.md` if any, `git status`, and the relevant history and diffs. Preserve unrelated working changes.
2. **No changelog yet:** examine every commit reachable from `HEAD`:
   `git log HEAD --no-merges --date=short --format='%h %ad %s'`
   Group substantive changes by commit author date and include every date that has any. Read commit bodies and diffs where the subject is unclear. Never invent dates.
3. **Changelog exists:** keep all existing entries. Find the target branch (the user's choice, else the default branch, normally `main`) and inspect commits and the diff from the merge base to `HEAD`. Also inspect staged, unstaged, and relevant untracked work meant for the merge. If already on the target branch, compare recent history with existing entries. Ask about the target or scope only if the answer would materially change the entries.
4. Use local history; do not fetch unless asked. Do not trust the newest heading date as a coverage marker, because several updates can land on one day. Compare the actual changes with the existing bullets.

## Write the entries

- Format: `# Changelog`, then `## YYYY-MM-DD` headings, newest first, plain `-` bullets, blank lines around headings and lists. No version headings and no Unreleased section.
- Dates: use the commit author date when bootstrapping or backfilling. For new work, use today's date in the user's timezone, adding to that day's heading if it exists rather than duplicating it.
- Content: concise English describing concrete behavior, fixes, or meaningful project and documentation changes. Combine related commits. Skip empty merges and anything already covered. Include substantive conflict-resolution changes from merge commits.
- Include only what history or inspected diffs support. Exclude local-only settings and work outside the intended merge. Do not log the changelog update itself.
- Running it twice on the same inputs must leave the file unchanged.
- If branches left conflicting changelog text, keep distinct valid entries, merge duplicate headings and bullets, and restore descending date order.

## Finish

Review the diff for accurate dates, full coverage, and duplicates. Report which dates were added or updated, or say no update was needed. Leave the result uncommitted. Invoking this skill does not authorize staging, committing, merging, pushing, or deleting branches.
