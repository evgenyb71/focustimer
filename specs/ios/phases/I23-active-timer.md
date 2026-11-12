# I23 Make the active timer obvious

Status: verified

## Goal

At a glance, the user can tell whether Focus or Break is running, paused, or waiting. Today, running Focus and running Break share a white status card, with only a small grey label to tell them apart.

Roadmap exit check: a design note in this spec, then the SwiftUI change. Focus and Break look distinct in running, paused, and waiting states. User-reported simulator screenshots show the active timer can be identified at a glance, and accessibility labels name it.

## Decisions

User, 2026-11-12:

- **Treatment:** the status card gets the phase's accent tint and border, plus a large phase name with a symbol above the time. The matching row in the duration panel is highlighted in the same accent.
- **Colours:** Focus uses the app's existing teal. Break uses a soft sage that leads into the stronger green of "Cycle complete", so each phase keeps one colour family through to its end.
- **Paused:** keeps the phase's colour at lower intensity, with a pause symbol and the label "Focus paused" or "Break paused".
- **Checks:** Cmd+U; screenshots on the user's simulator of the five states below; a quick VoiceOver listen to the status card. The agent also takes screenshots on its own simulator.

### Design note (agent draft, open to revision before the SwiftUI change)

| | Focus running | Focus paused | Waiting for Break | Break running | Break paused |
| --- | --- | --- | --- | --- | --- |
| Card | Teal tint and border | Lighter teal tint, thin border | Amber, unchanged from I24 | Sage tint and border | Lighter sage tint, thin border |
| Phase name and symbol | "Focus", `brain.head.profile` | "Focus", `pause.circle.fill` | Cup and "Focus complete" (I24) | "Break", `leaf.fill` | "Break", `pause.circle.fill` |
| Small label | "Running" | "Paused" | none | "Running" | "Paused" |
| Time | Large, in the accent | Large, secondary colour | Hidden (I24) | Large, in the accent | Large, secondary colour |
| Duration panel | Focus row highlighted in teal | Focus row highlighted, lighter | Dimmed (I24) | Break row highlighted in sage | Break row highlighted, lighter |

- Idle and "Cycle complete" stay as they are. The Start button remains teal, since it starts Focus.
- The row highlight is a tinted background with an accent bar at its leading edge. It does not change the Stepper, which is disabled while running anyway.
- **Final colours:** Focus teal RGB (0.16, 0.44, 0.42), the Start button's colour. Break sage RGB (0.28, 0.44, 0.26), greyer and more yellow than the "Cycle complete" green (0.18, 0.48, 0.27). The card tint is 14 % of the accent while running and 7 % while paused; the border is 60 % at 2 pt running and 35 % at 1 pt paused.
- **Contrast** (agent-computed, WCAG relative luminance, on the card tint over the top and bottom of the background gradient): teal 4.3 to 5.1, sage 4.3 to 5.0. The accent is used only for the phase name (28 pt bold) and the time (48 pt), which need 3:1 as large text. The small label stays in the secondary colour. The duration-row title uses the accent at caption size, at about 4.3:1, slightly under the 4.5:1 for small text; worth revisiting in I19.
- **Accessibility:** the symbol is decorative. The phase name, the label, and the time read as one element, for example "Focus, running, 12 minutes 30 seconds remaining". The highlighted duration row adds the value "active". The pause and cancel labels stay as they are. A correction or scheduling notice still replaces the status line.

Agent decisions, open to revision:

- **Model:** a small computed presentation in `TimerStore` for the active phase (which phase, whether paused) and the spoken status label, so tests check them without the view. `ContentView` maps it to colours and symbols, as it does for `endState`.
- **Wording:** the existing status titles ("Focus Timer running", "Focus paused") give way to the phase name plus "Running" or "Paused". The status line below the time is unchanged.
- **Saved data:** no change, and no new `schemaVersion`.

## Non-goals

- Changing the I24 end screens, idle, or the background gradient.
- Animations between states, or a Live Activity or widget.
- A full VoiceOver, Dynamic Type, and contrast review (I19).
- The app icon (I20).

## Plan

Tick an item only when it is done.

- [x] Add the active-phase presentation and spoken status label to `TimerStore`.
- [x] Restyle the status card for running and paused Focus and Break.
- [x] Highlight the active row in the duration panel.
- [x] Choose and record final colours with their contrast ratios in the design note.
- [x] Add the Swift Testing tests listed under Checks.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] Take agent screenshots of the five states on iPhone 17 Pro, iOS 26.5.
- [x] User: run Cmd+U, take the five screenshots, and listen to the status card with VoiceOver; record in Results as user-reported.
- [x] Update the [mission](../mission.md) UI description and the [tech stack](../tech-stack.md) source map if they change.
- [x] Set `Status: verified` and move the roadmap row to Completed.
- [ ] Open the PR with screenshots; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run: `scripts/test.sh`, with Swift Testing tests covering:

- The active presentation is Focus while Focus runs or is paused, Break while Break runs or is paused, and none in idle, waiting, and completed.
- The paused flag follows Pause and Resume.
- The spoken label names the phase, running or paused, and the remaining time, and updates as the time changes.
- Waiting and completed keep their I24 end states.

Agent screenshots of the five states, using `scripts/debug-minute.sh` on its own simulator.

User-reported, in Xcode:

- Cmd+U passes.
- Screenshots on the user's simulator of Focus running, Focus paused, waiting for Break, Break running, and Break paused, showing which timer is active at a glance.
- With VoiceOver, the status card reads the phase, running or paused, and the time.

Stays unverified: colour perception for colour-blind users beyond the names and symbols; the largest text sizes (I19); a physical device.

## Results

Agent-run, 2026-11-12, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 247, passed 247, failed 0, skipped 0, expected failures 0
PASSED
```

New tests are in `TimerStoreActiveTimerTests`.

Agent screenshots, 2026-11-12, iPhone 17 Pro, iOS 26.5, Debug build. Each state was seeded into the app's saved data before launch instead of using `scripts/debug-minute.sh`, since the agent cannot tap the simulator. All five match the design note: teal Focus and sage Break cards with the matching duration row highlighted, lighter cards with a grey time and a pause symbol while paused, and the unchanged amber waiting screen.

User-reported, 2026-11-12, on the user's simulator: Cmd+U passed; the screenshots of Focus running, Focus paused, waiting for Break, Break running, and Break paused show which timer is active at a glance; with VoiceOver, the status card read the phase, running or paused, and the time. The user's screenshots go in the PR.

Remaining limitations: colour perception for colour-blind users rests on the names and symbols; the duration-row title in the accent is about 4.3:1 at caption size (I19); the largest text sizes (I19); a physical device. The line under the time keeps the app's teal on the Break card, a possible later tweak.

