# I24 Design Focus-end and Break-end states

Status: verified (2026-10-27): 121 test functions, all passed, 0 expected failures, agent-run on iPhone 17 Pro iOS 26.5, with agent screenshots of both ends; user-reported Cmd+U as expected and a full cycle on the iPhone 18 Pro Max (iOS 27.0) with both end screens as expected. The user confirmed the screens by sight and did not send screenshots; the exit check's screenshots are the agent's. Implements roadmap phase I24, "Design Focus-end and Break-end states", scheduled before I13. Commit `58cd74b` (changelog `92178eb`) on branch `feat/I24-end-states`; Codex review approved (as reported by the user, 2026-10-27); merged to `main` as `a660f4b` and pushed.

Context: [roadmap](../roadmap.md), [mission](../mission.md), [tech stack](../tech-stack.md), previous phase [I12](I12-expiry-clock-edges.md).

Roadmap exit check: a design note in this spec, then the SwiftUI change. Focus end (waiting for Break confirmation) and Break end each have a clearly distinct presentation with the next action visible. User-reported screenshots confirm both ends are unmistakable. This phase supplies the Break-end presentation that I13 to I15 build on.

## Requirements

### Scope

Today both ends look like any other state: the status card shows a small uppercase title ("Focus Timer complete"), the time (`00:00` while waiting, `--:--` in idle), and one line of text. Break end is just idle again ("Ready"), so nothing tells the user a cycle has finished. This phase designs both ends and builds them in SwiftUI.

### Decisions (user, 2026-10-27)

- **Order:** I24 is planned before I13, so I13 builds on the agreed Break-end presentation.
- **Break end before I13: a transient flag.** When Break completes, `TimerStore` sets an unsaved "Break just finished" flag. The Break-end presentation shows while the flag is set and the app is idle. It clears on the next action (Start or Cancel) and is gone after a relaunch. I13 replaces the flag with the durable completed state and reuses the same view.
- **Style: restyle the status card.** The layout stays the same. At each end the status card gets its own accent color, a large SF Symbol, a clear headline, and a one-line next step, and the primary button names the next action. The duration panel stays visible but quieter.
- **Validation:** agent-run unit tests, agent screenshots of both ends on its own iPhone 17 Pro simulator, user-reported Cmd+U, and user-reported confirmation with screenshots on the iPhone 18 Pro Max.

### Design note (agent draft for review)

| | Running (unchanged) | Focus end (waiting for Break confirmation) | Break end (Break just finished) |
| --- | --- | --- | --- |
| Card accent | Current white card | Warm amber tint and border | Calm green tint and border |
| Symbol | none | `cup.and.saucer.fill` | `checkmark.circle.fill` |
| Headline (replaces the time) | `mm:ss` | "Focus complete" | "Cycle complete" |
| Next step line | current status message | "Take a break when you're ready." | "Start another Focus when you're ready." |
| Primary button | Start / Start Break | "Start Break", amber | "Start Focus", green |
| Duration panel | normal | 60 % opacity | normal (editable, since the app is idle) |

- The symbol is large (about 56 pt) above the headline; the time is hidden at the ends, because `00:00` and `--:--` read as an empty timer rather than an outcome.
- Colors are chosen from the existing warm palette and must keep text contrast at WCAG AA against the card. I23 (making the active timer obvious) may adjust running colors later; the end colors are picked so they stay distinct from any running accent.
- **Accessibility:** the symbol is decorative (hidden from VoiceOver); the headline and next-step line are read as one element ("Focus complete. Take a break when you're ready."), and the primary button keeps its visible label. The correction notice from I07 to I12, when shown, still replaces the next-step line.
- Copy and colors are a draft; change them in this table before implementation if you prefer others.

### Agent decisions within the user's choices (open to revision)

- **Presentation model:** a small enum in `TimerStore`, for example `endState: EndState?` with `.focusComplete` and `.breakComplete`, computed from the phase and the transient flag. `ContentView` switches on it. I13 then maps `.completed` to `.breakComplete` without view changes.
- **Flag lifetime:** set in `handlePhaseCompletion()` when Break completes, including when launch or activation reconciles a Break that ended while the app was suspended. Cleared by Start, Cancel, and any duration edit. Not saved, so a relaunch after the Break end shows the normal idle screen. This is acknowledged as a stopgap until I13.
- **Primary button label in Break end:** "Start Focus" instead of "Start", to name the next action; idle without the flag keeps "Start".
- **No new transitions:** both ends use the existing actions (Start Break while waiting; Start or Cancel at Break end). Done and Restart are I14 and I15.

### Notes carried to I13 (user decisions, 2026-10-27)

Asked during the I13 planning that was paused for this phase; record them in the I13 spec when it is written:

- The completed state keeps the finished cycle's ID, so I16 can validate a Break alert against it. Only idle has no cycle ID.
- Saved data moves to schema version 3 with a no-op 2 → 3 step, so builds before I13 treat data that may contain "completed" as a newer version (I09) instead of failing to decode it.
- The delivered Break alert stays while the app is completed (it is the current alert), and is removed when the user leaves completed. This changes the I11 activation rule for that state.
- The I13 scope question (how to leave completed before I14 and I15) is still open.

### Non-goals

- The durable completed state, Done, and Restart (I13 to I15); notification actions (I16, I17).
- Running and paused presentation (I23), launch-state policy (I22), and the full accessibility pass (I19).
- Animations beyond SwiftUI's default transitions, sounds, or haptics.
- Dark-mode redesign; the app keeps its fixed light background.

### Affected components

- `ios/FocusTimer/FocusTimer/ContentView.swift`: end-state presentation of the status card, primary button style and label, quieter duration panel while waiting.
- `ios/FocusTimer/FocusTimer/TimerStore.swift`: the end-state enum, the transient Break-end flag and when it is set and cleared, the primary button title.
- `ios/FocusTimer/FocusTimerTests/FocusTimerTests.swift`: tests for the end-state enum and the flag lifetime.
- Docs after verification: [mission](../mission.md) baseline (UI line) and [tech stack](../tech-stack.md) if the store gains the flag.

### Invariants to preserve

- A single authoritative timer state in `TimerStore`; the end-state enum is derived, and the flag is presentation only, never saved and never driving transitions.
- Explicit Break confirmation: the Focus-end screen still requires Start Break; nothing starts Break automatically.
- Local persistence and deadline-based recovery are unchanged; saved data does not change in this phase.

## Plan

1. **Store**
   - [x] Add the end-state enum and the transient Break-end flag; set and clear it as described; Break-end primary button title.
2. **View**
   - [x] Restyle the status card for both ends (accent, symbol, headline, next step, accessibility grouping); style the primary button per end; dim the duration panel while waiting.
3. **Tests** (Swift Testing)
   - [x] End state is `.focusComplete` only while waiting, `.breakComplete` only after Break completes and before the next action, and nil otherwise.
   - [x] The flag is set when Break completes in the app and when launch or activation reconciles a finished Break; cleared by Start, Cancel, and a duration edit; absent after a relaunch; not written to the store.
   - [x] Existing tests pass.
4. **Screenshots and docs**
   - [x] Agent screenshots of Focus end and Break end on the iPhone 17 Pro simulator, stored outside the repository and described here.
   - [x] Record results; update the mission's UI line and the tech stack.

## Validation

### Agent-run

Run after the Swift changes. Toolchain checks per `AGENTS.md` (`xcode-select -p`, `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list`). Then, from the repository root, on iPhone 17 Pro (iOS 26.5), not the user's simulator:

```sh
xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath /tmp/FocusTimerTests-$(date +%Y%m%d-%H%M%S).xcresult CODE_SIGNING_ALLOWED=NO test
```

Record `totalTestCount`, `passedTests`, `failedTests`, and expected failures from `xcrun xcresulttool get test-results summary --path <result bundle>`. Expected: the 109-function I12 baseline plus the new tests, all passing, 0 expected failures.

Screenshots: install the build on the iPhone 17 Pro simulator, set Focus and Break to 1 min, and capture the Focus-end and Break-end screens (`xcrun simctl io <device> screenshot`). Shut down the simulator afterwards.

### User-reported (Xcode)

- Product > Test (Cmd+U) passes; report the summary line.
- On the iPhone 18 Pro Max (iOS 27.0), with Focus and Break at 1 min: let Focus end and confirm the Focus-end screen; start Break, let it end, and confirm the Break-end screen. Send a screenshot of each and say whether both read as unmistakable.

### Remains unverified

- VoiceOver reading order and Dynamic Type at the largest sizes (I19).
- Contrast measured with a tool; this phase relies on the chosen palette.
- The Break-end screen after a relaunch (by design it is gone until I13).

## Results

### Agent-run (2026-10-27)

- Toolchain: `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`; Xcode 27.1; destination iPhone 17 Pro, iOS 26.5 (the user's iPhone 18 Pro Max was not used).
- Tests (`/tmp/FocusTimerTests-20261027-211943.xcresult`): `** TEST SUCCEEDED **`. `xcresulttool get test-results summary`: result Passed, `totalTestCount` 121, `passedTests` 121, `failedTests` 0, `skippedTests` 0, `expectedFailures` 0. That is the 109 I12 functions plus 12 new `TimerStoreEndStateTests` functions. Passed on the first run. No compiler warnings.
- Screenshots: the agent booted the iPhone 17 Pro simulator, installed the Debug build, and seeded the app's container preferences with `xcrun simctl spawn … defaults write` while the app was stopped. Focus end: `state` waiting for Break with a cycle ID. Break end: a running Break with an expired deadline, which launch reconciled to idle with the Break-end flag set. Captured with `xcrun simctl io … screenshot`; files kept outside the repository (agent scratchpad) and sent to the user. The simulator was shut down afterwards.
  - Focus end: amber card tint and border, cup symbol, "Focus complete", "Take a break when you're ready.", amber "Start Break" button, dimmed duration panel. No time shown.
  - Break end: green card tint and border, checkmark symbol, "Cycle complete", "Start another Focus when you're ready.", green "Start Focus" button, duration panel at full strength.

### Implementation notes

- `TimerStore.EndState` (`.focusComplete`, `.breakComplete`) and `endState` are derived from the phase and `breakJustFinished`. `endHeadline` holds the headline text; `statusMessage` holds the next-step line, and the I07 correction notice still replaces it.
- `breakJustFinished` is set in `handlePhaseCompletion()` for Break, so in-app completion, activation, and launch reconciliation all set it. It is cleared by `startFocus()`, `cancel()`, and a `didSet` on `configuration` (any duration edit). It is `@Published` and never written to the store.
- Copy changes: the waiting message changed from "Press Start Break to begin." to "Take a break when you're ready."; idle after Break shows "Start another Focus when you're ready."; the primary button reads "Start Focus" at Break end.
- `ContentView` hides the small status title and the time at the ends, shows the symbol (hidden from VoiceOver) above the headline, and groups the headline and next-step line into one accessibility element. The accent colors live in a private `EndState` extension; their contrast with white button text was computed, not measured with a tool: about 4.9:1 (amber) and 5.3:1 (green).

### User-reported

- 2026-10-27, Cmd+U in Xcode 27.1 (iPhone 18 Pro Max simulator, iOS 27.0): reported "done and as expected" by the user; the summary line with the count was not included.
- 2026-10-27, full cycle on the iPhone 18 Pro Max (iOS 27.0): the user ran Focus, waited for its end, started Break, and waited for its end, and reported that both end screens look as expected. No user screenshots were sent; the agent screenshots above are the recorded images.
