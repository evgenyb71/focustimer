# I28 Verify with an accessibility audit and VoiceOver

Status: verified

## Goal

The app passes Apple's accessibility audit on each main screen, and VoiceOver users can run a full Focus → Break cycle, including from the alerts. This closes the checks deferred from [I19](I19-accessibility.md) and the alert-action VoiceOver gap left by I16 and I17.

Roadmap exit check: an audit of idle, Focus running, paused, waiting for Break, and Cycle complete with no unexplained issues; a VoiceOver walk through one full cycle with every control labelled and the order following the screen. User-reported.

Exit check status: **partly met.** All five screens are audited at both text sizes, including the parts below the fold at the largest size, and four findings are fixed. One issue stays unexplained: the audit flags the header subtitle for contrast although it measures well above the target. It is allowed in the test with a TODO, at the user's request. That allowance also passes any contrast issue reported without an element, so a passing audit does not prove the subtitle is the only one affected. Contrast is audited on the first screenful only; below the fold it rests on `PaletteContrastTests` (see the review section). The VoiceOver walk is user-reported as a best-effort pass, not step by step.

## Decisions

User, 2026-11-19:

- **Automated audit:** add the planned XCTest UI-test target, with a test that opens each main screen and runs Apple's accessibility audit, the same checks the Accessibility Inspector runs. The agent runs it with `scripts/test.sh --ui`, so the user's part is the VoiceOver walk. The roadmap row's Inspector audit is met by this test; the user may still run the Inspector.
- **Failing part allowed, not the whole audit** (2026-11-19): the user first had both audit tests skipped, then asked to disable only the failing part. The test now allows only the subtitle contrast issue described under Audit findings, with a TODO; everything else in the audit runs and must pass.
- **Separate scheme:** the UI tests run from their own shared scheme, "FocusTimer UI Tests", so Cmd+U on FocusTimer stays unit tests only and fast. From the terminal, `scripts/test.sh --ui` runs the UI scheme; plain `scripts/test.sh` runs the unit tests as before.
- **Fixes:** contained issues found by the audit or the walk (labels, order, hints, small layout) are fixed in this phase; anything bigger becomes its own phase.
- **Alerts:** the VoiceOver walk includes the alert actions OK, Restart, and Done.

Agent decisions, open to revision:

- **Reaching each screen:** revised during the build: instead of tapping through with short minutes, each launch seeds the saved configuration and timer through launch arguments (`-config`, `-state`, `-schemaVersion` as property-list data), which override the stored values for that launch only. A phase that ended before launch shows its end screen once, which reaches waiting and Cycle complete. No test-only code goes into the app, and each screen is exact and immediate.
- **Audit scope:** all audit categories, at the default and the largest accessibility text size. At the largest size the test audits four screenfuls, swiping between them, and fails unless each element the screen is about (the status card, Start, Start Break, Restart, Done) came into view during one of them. Scrolled screenfuls skip the contrast category; see the review section. An issue that cannot be fixed is allowed in the test by its type and element only, with the reason recorded here. Two allowances exist: contrast on a disabled button (WCAG exempts inactive controls), and the subtitle contrast TODO. The second also lets through contrast issues with no element attached, because the audit sometimes reports the subtitle without naming it; this is broader than planned and is the first thing to remove when the TODO is resolved.
- **Visible design changes from the audit:** the pause, cancel, and Done buttons changed from bordered glass to solid fills (teal with white icons; dark grey with a white label), and secondary text is darker in both themes. Reviewers should expect these in screenshots.
- **Test target:** a new `FocusTimerUITests` target with a synchronized folder like the unit tests, in its own scheme (above).
- **Saved data:** no change, and no new `schemaVersion`.

### Audit findings (agent, 2026-11-19, iPhone 17 Pro, iOS 26.5)

All are contrast findings. The audit found no label, hit-area, or Dynamic Type issues with the shipped layout; a hit-area issue appeared only during the plain-button experiment below, which was reverted.

- [x] **Secondary text** failed, first seen on the subtitle "Run Focus, confirm, then run Break.". Darkened in both themes, in light mode from 5.2 to 6.5:1 to 6.9 to 8.7:1 (over the gradient's darker end, then over the card). This did not clear the subtitle issue; see the last item.
- [x] **Done button** failed: accent text on the bordered button's light glass. Fixed: a solid neutral fill with a white label.
- [x] **Pause and cancel buttons** failed while a timer ran: a teal icon on light glass. Shown by an experiment with plain buttons, which removed the issue but made the hit area too small. Fixed: solid teal fills with white icons.
- [x] **Disabled Start button** while a timer runs. Allowed in the test: WCAG exempts inactive controls.
- [ ] **Subtitle still flagged** "Run Focus, confirm, then run Break.", on most screens at the largest text size and on iOS 26.5 also while a timer runs, sometimes with no element named. It is dark grey on cream, well above 4.5:1 by the palette's measurement, so the audit's reading looks wrong. Allowed in the test with a TODO: contrast issues on that label or with no element pass; every other contrast issue still fails. Next step: find out why the audit measures it lower (font weight, the gradient behind it), fix it, and remove the allowance.

### Decision log

In order, so a reviewer can follow how the phase reached its current shape. All 2026-11-19.

1. **Planning.** The user was short on time after I19, so the agent proposed an automated audit to replace the manual Inspector pass. The user chose: add a UI-test audit, fix contained issues here, and include the alert actions in the VoiceOver walk.
2. **Target added.** The `FocusTimerUITests` target was added by hand to the project file, following the unit-test target, and first placed in the FocusTimer scheme.
3. **Reaching screens.** The plan was to tap through with short minutes. During the build this changed to seeding saved data through launch arguments, which is exact, immediate, and needs no app code.
4. **First audit run.** Every screen failed contrast. The secondary text and Done button were fixed, and the disabled Start button was allowed. Some issues then came back with no element attached.
5. **Experiment.** Switching the header buttons to a plain style removed one unidentified issue, which showed it was the pause button's teal icon on glass. Plain buttons failed the hit-area check, so the experiment was reverted and the buttons got solid fills.
6. **Remaining issues.** The rest stayed unidentified, and nothing on screen looked faint. The agent guessed the system steppers and offered custom +/- buttons, or allowing the issues. The user chose to skip both audit tests with a TODO.
7. **User's first Cmd+U.** It ran before the skip landed and showed the old failures. On the user's iPhone 18 Pro Max, iOS 27.0, only the largest-size test failed, while the agent's iOS 26.5 run also failed the default size. The log line "AX Safe category class 'SLHighlightDisambiguationPillViewAccessibility' was not found!" comes from iOS's own accessibility system in the simulator and is not related to the app.
8. **Reversal.** The user noticed that no UI tests ran and asked to disable only the failing part, and to give UI tests their own scheme so they can be run separately. The skips were removed, the UI target moved to the new "FocusTimer UI Tests" scheme, and `scripts/test.sh --ui` was added.
9. **Subtitle identified.** The next run attached the element to the issues: the subtitle, not the steppers. The allowance was narrowed to contrast on that label, or with no element, under a TODO. Both UI tests then passed.
10. **User checks.** Cmd+U passed on both schemes on iOS 27.0. The VoiceOver walk was done as a best effort and found nothing; the user asked to mark it tested.
11. **Codex review: scrolling.** The audit had never scrolled, so at the largest size the lower content was not covered. Adding scrolling showed that XCUITest reports stale frames for these SwiftUI elements after a scroll: end-of-scroll detection never fired, and contrast issues were pinned on off-screen elements (the black title "Focus / Break Timer") or sampled wrong pixels (an all-black picture of the Done button, which a real screenshot shows as a white label on the dark fill). Two experiments were tried and reverted: a near-black Done fill, and a solid top scroll edge, which removed the title artefact once but not reliably. The final shape: a fixed four screenfuls at the largest size, a check that each key element came into view, and no contrast category on scrolled screenfuls, whose contrast `PaletteContrastTests` already covers.

Separately, the user asked that the agent never run `rm` in any form, and always ask them to run deletions. This followed a blocked `rm -rf` on a scratch folder during step 4; nothing was deleted. It was first recorded in the agent's memory and, after the Codex review, added to `AGENTS.md` so both agents follow it.

## Non-goals

- Switch Control and Voice Control beyond the labels.
- Other UI tests beyond the audit; the target makes them possible later.
- Colour-blind simulation.

## Plan

Tick an item only when it is done.

- [x] Add the `FocusTimerUITests` target to the project and scheme.
- [x] Write the audit test for idle, Focus running, paused, waiting for Break, and Cycle complete, at the default and largest text size.
- [x] Run it, fix contained findings, and record each finding and any allowed issue here. The remaining subtitle issue is allowed with a TODO, at the user's request.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] User: Cmd+U, and the VoiceOver walk below; record in Results as user-reported.
- [x] Fix contained findings from the walk, and rerun the affected checks. None reported.
- [x] Update the [mission](../mission.md) "Not yet verified" and "Still to build", the [tech stack](../tech-stack.md) testing row and source map, and `AGENTS.md` on the UI-test target.
- [x] Set `Status: verified` and move the roadmap row to Completed.
- [ ] Open the PR; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run: `scripts/test.sh` for the unit tests, and `scripts/test.sh --ui` for the audit at both text sizes.

User-reported, in Xcode, with VoiceOver on and `scripts/debug-minute.sh 10`:

1. Cmd+U passes on both schemes, FocusTimer and FocusTimer UI Tests.
2. In idle, swipe through every element: each is named, and the order follows the screen.
3. Start Focus; the status card reads the phase, "running", and the time. Pause and resume by VoiceOver.
4. Let Focus end with the app open; "Focus complete" is announced or found, and Start Break is reachable.
5. Let Break end; Restart and Done are reachable and named.
6. In the background, let Focus end and use OK on the alert with VoiceOver; then let Break end and use Restart, and on another cycle Done.

Stays unverified: a physical device; Switch Control and Voice Control.

## Results

Agent-run, 2026-11-19, on iPhone 17 Pro, iOS 26.5:

```text
FocusTimer on iPhone 17 Pro, iOS 26.5: total 258, passed 258, failed 0, skipped 0, expected failures 0
PASSED
FocusTimer UI Tests on iPhone 17 Pro, iOS 26.5: total 2, passed 2, failed 0, skipped 0, expected failures 0
PASSED
```

The UI tests audit all five screens at both text sizes, with the subtitle allowance above.

User-reported, 2026-11-19, on the user's simulator (iPhone 18 Pro Max, iOS 27.0): Cmd+U passed on both the FocusTimer and the FocusTimer UI Tests schemes. The user walked through the VoiceOver steps with `scripts/debug-minute.sh 10` as far as they could and found everything working, with no findings; the user asked for it to be marked as tested. Step-by-step results were not recorded.

Remaining limitations: the subtitle contrast allowance (TODO above); VoiceOver checked as a best-effort walk on the simulator, not step by step and not on a physical device; Switch Control and Voice Control.

### Review

Codex review of the first PR revision: one P2 finding, fixed, and documentation notes, addressed.

- **[P2] The audit did not cover content below the fold at the largest size.** Fixed: the test now scrolls through four screenfuls and fails unless each key element came into view (decision log, step 11). The first scrolled run confirmed the gap: Restart, Done, and Start Break had never been audited. Scrolled screenfuls skip the contrast category because of XCUITest's stale frames there; their contrast is covered by the palette unit tests.
- **The no-element allowance is broad.** Agreed and now stated wherever the audit is summarised: here, the mission, the README, the test comment, and the PR.
- **README** now describes the audit and its open exception.
- **The no-`rm` rule** is now in `AGENTS.md`, so both agents follow it.
- **Screenshots** of the solid header and Done buttons are for the user to attach to the PR.

After the fixes, agent-run on iPhone 17 Pro, iOS 26.5:

```text
FocusTimer on iPhone 17 Pro, iOS 26.5: total 258, passed 258, failed 0, skipped 0, expected failures 0
PASSED
FocusTimer UI Tests on iPhone 17 Pro, iOS 26.5: total 2, passed 2, failed 0, skipped 0, expected failures 0
PASSED
```

Codex re-review: recommended merging with the recorded limitations. Two nonblocking notes, both done: `filledButtonsKeepWhiteLabelsReadable` now also checks white on the Done button's neutral fill, and the decision log no longer says the no-`rm` rule lives only in agent memory. Codex also noted that the palette tests are numerical evidence, not a complete rendered contrast audit below the fold; that limitation stands as recorded.
