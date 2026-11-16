# I19 Verify accessibility and visual resilience

Status: verified

## Goal

The app works well with VoiceOver, at every Dynamic Type size, and in both light and dark mode. Every control has a clear label, the reading order follows the screen, text meets contrast targets, and nothing is cut off at the largest accessibility text size.

Roadmap exit check: VoiceOver, Dynamic Type, contrast, focus and reading order, control labels, and the largest supported text sizes are checked.

## Decisions

User, 2026-11-16:

- **Scope:** audit, then fix what is found when the fix is contained: labels, contrast, reading order, and layout at large text. Anything bigger is recorded here and scheduled as its own phase.
- **Dark mode:** a proper dark theme, with dark versions of the background, cards, and accents, instead of locking the app to light. Today the colours are fixed for light, so standard text likely turns white on the cream cards in dark mode.
- **Dynamic Type:** every size up to the largest accessibility size. The time and headlines scale, rows stack when they do not fit, and nothing is clipped; the screen already scrolls.
- **Checks:** the user runs Xcode's Accessibility Inspector audit on each main screen, walks one full cycle with VoiceOver, and takes screenshots at the largest accessibility text size and in dark mode. The agent takes its own screenshots and contrast measurements.

Agent decisions, open to revision:

- **Size:** the dark theme is the largest part. If the change becomes too large to review with the audit fixes, it lands as a first PR within this phase, and the audit fixes follow in a second, both recorded in this spec.
- **Colours:** one Swift palette, each colour with a light and a dark value, replaces the fixed RGB values in the view, so both themes are defined in one place. Revised from asset-catalog colours during the build: keeping the values in code lets unit tests check every text and background pair against the contrast targets. The app icon is unchanged; it already has a dark version.
- **Dark palette:** a deep warm brown-grey background and slightly lighter cards; teal, sage, amber, and green lightened enough to meet contrast on them. The light accents are slightly darker than in I23 and I24, so small text meets 4.5:1. Filled buttons keep the light accent in both themes, so their white label stays readable. Values live in the palette; the lowest ratios over the plain card and every tinted card are:

  | Colour | Light | Dark | Used for |
  | --- | --- | --- | --- |
  | Primary text | 13.8 | 9.1 | Headlines, durations |
  | Secondary text | 5.3 | 4.8 | Captions, subtitle, hint |
  | Status line | 6.6 | 6.4 | Message under the time |
  | Focus teal | 5.4 | 5.2 | Phase name, time, row title |
  | Break sage | 5.3 | 5.6 | Phase name, time, row title |
  | Focus-end amber | 4.7 | 5.4 | End symbol (large) |
  | Break-end green | 4.6 | 5.6 | End symbol (large) |
- **Contrast targets:** WCAG AA, 4.5:1 for small text and 3:1 for large text and symbols, in both themes. This includes the I23 notes: the "Running" and "Paused" captions (about 3.4:1) and the duration-row title in the accent (about 4.3:1).
- **Fixed sizes:** the 48 pt time and the 56 pt end symbol scale with Dynamic Type, capped at 96 pt and 112 pt; the time also shrinks to fit one line if needed.
- **Large text layout:** at accessibility sizes, the header buttons move above the title, which gets the full width, and each duration row places its stepper under the label.
- **VoiceOver fixes:** the idle card reads as one stop, "Ready, No timer running, Set durations and press Start."; each duration row reads its title and "25 minutes", plus "active" for the running phase.
- **Saved data:** no change, and no new `schemaVersion`.

### Audit findings (agent, 2026-11-16, iPhone 17 Pro, iOS 26.5)

From screenshots of seeded states in dark mode and at the largest accessibility text size, and a reading of the view code:

- [x] **Dark mode is unreadable.** The background and cards stay cream while standard text turns white: the title, subtitle, idle duration row, and "RUNNING" caption all but vanish. Fixed: light and dark palette; agent dark-mode screenshots readable throughout.
- [x] **The header breaks at large text.** The pause and cancel buttons keep their width, so the title wraps one syllable per line ("Fo-cus / Break Timer") and the header fills the first screen. Fixed: at accessibility sizes the buttons move above the title; agent screenshots at the largest size.
- [x] **The time and end symbol do not scale.** The 48 pt time and 56 pt symbol stay fixed while the text around them grows, so at the largest size the time is smaller than its own caption. Fixed: both scale, capped at 96 pt and 112 pt, the time on one line; agent screenshots at the largest size.
- [x] **Duration rows are cramped at large text.** The title wraps beside the stepper; stacking the stepper under the label reads better. Fixed: the stepper sits under the label at accessibility sizes; agent screenshots at the largest size.
- [x] **Small-text contrast falls short** (from I23): "Running" and "Paused" at about 3.4:1, and the duration-row title in the accent at about 4.3:1. Fixed: darker secondary text and accents; `PaletteContrastTests` checks 4.5:1 in both themes.
- [x] **VoiceOver reads the idle time as symbols.** `--:--` has no label, and the idle card's caption, time, and message are three separate stops. Fixed: the idle card is one stop with "No timer running"; unit-tested, VoiceOver itself deferred to I28.
- [x] **The duration rows speak "min".** Their label is the uppercase title and "25 min"; a spoken "25 minutes" is clearer. Fixed: rows read their title and "25 minutes", plus "active"; unit-tested, VoiceOver itself deferred to I28.

Found by the user during the build, 2026-11-16:

- [x] **The app crashed on Pause, and froze on every relaunch.** SwiftUI resolves colours on its background render thread too. The new light/dark colour provider was a closure tied to the main actor under Swift 6, so resolving it there trapped (`_dispatch_assert_queue_fail` in `Palette.Pair.color`, on `com.apple.SwiftUI.AsyncRenderer`). Pause happened to trigger it; after that the saved paused state hit it at once on each launch, and Xcode's debugger held the app, so the controls looked frozen. Fixed: the provider is a nonisolated `@Sendable` closure. `PaletteThreadingTests` resolves a colour off the main thread, and the agent reproduced the crash on its simulator and confirmed Pause works after the fix.
- [x] **The Start button had dark text in light mode.** A text colour set on the whole screen overrode the filled buttons' white label, and also the pause, cancel, and Done colours. Fixed: the screen-wide colour is gone, and primary text uses the system style again; the palette's primary text mirrors it for the contrast tests. Agent screenshot shows white "Start" on teal.

Reading order otherwise follows the screen: title, subtitle, pause, cancel, the two rows, the status card, the buttons, and the alerts hint. Pause, cancel, and the primary buttons are labelled.

## Non-goals

- Notification alert content and actions; iOS draws those, and their VoiceOver behaviour stays a limitation of I16 and I17.
- New features, wording changes beyond labels, or landscape support.
- Hiding the completion banner while the app is open, raised by the user during the build; scheduled as I27, sound kept.
- An automated accessibility audit test target; worth revisiting with the planned UI-test target.

## Plan

Tick an item only when it is done.

- [x] Audit the current app: screenshots in dark mode and at the largest text size, contrast measurements, and the label and reading order of each element. Record the findings here.
- [x] Move the app's colours into named light and dark colours, and add the dark theme.
- [x] Fix contrast findings in both themes, including the I23 captions and duration-row title.
- [x] Make the fixed-size time and symbols scale, and adapt the duration rows and header at accessibility sizes.
- [x] Fix label and reading-order findings.
- [x] Add Swift Testing tests for any changed store logic, such as labels.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] Take agent screenshots in light and dark at the default and largest text sizes for idle, Focus running, waiting for Break, and Cycle complete; record contrast ratios.
- [x] User: check light and dark mode and small, large, and bold text; record in Results as user-reported. The Accessibility Inspector audit and the VoiceOver cycle are deferred to I28 at the user's request.
- [x] Update the [mission](../mission.md) UI description and "Still to build", and the [tech stack](../tech-stack.md) notes on colours.
- [x] Set `Status: verified` and move the roadmap row to Completed.
- [ ] Open the PR with screenshots; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run:

- `scripts/test.sh`, with tests for any changed labels or store logic.
- Screenshots in light and dark, at the default and the largest accessibility text size, using seeded saved state and `xcrun simctl ui` for appearance and text size.
- Contrast ratios computed for each text and accent colour against its background, in both themes.

User-reported, in Xcode:

- Accessibility Inspector audit of idle, Focus running, paused, waiting for Break, and Cycle complete, with no remaining issues or each one explained.
- VoiceOver through one full cycle: every control is labelled, the order follows the screen, and the status card reads the phase and time.
- Screenshots at the largest accessibility text size and in dark mode, with nothing clipped or unreadable.

Stays unverified: Switch Control and Voice Control beyond the labels; colour perception for colour-blind users beyond the names and symbols; a physical device.

## Results

Agent-run, 2026-11-16, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 255, passed 255, failed 0, skipped 0, expected failures 0
PASSED
```

After the crash and Start-label fixes, same simulator:

```text
iPhone 17 Pro, iOS 26.5: total 256, passed 256, failed 0, skipped 0, expected failures 0
PASSED
```

New tests: `PaletteContrastTests` checks every text and accent colour against the plain and tinted cards and the background, in both themes, at 4.5:1 for small text and 3:1 for large text, plus white on the filled buttons. `TimerStoreActiveTimerTests` adds the idle time and duration-row labels.

Agent screenshots, 2026-11-16, iPhone 17 Pro, iOS 26.5, Debug build, with seeded saved state and `xcrun simctl ui` for appearance and text size: idle, Focus running, waiting for Break, and Cycle complete, in light and dark, at the default size and the largest accessibility size. Dark mode is readable throughout. At the largest size the title wraps by word, the buttons sit above it, the steppers sit under their labels, and the time scales and stays on one line. Audit findings 1 to 7 are addressed; VoiceOver itself is left to the user check.

User-reported, 2026-11-16, on the user's simulator: Pause no longer crashes; light and dark mode, small and large text sizes, and Bold Text all work, with nothing unreadable or cut off.

Deferred to [I28](../roadmap.md) at the user's request: the Accessibility Inspector audit and the VoiceOver walk through a full cycle, including findings 6 and 7 as spoken.

Remaining limitations: VoiceOver and the Inspector audit (I28); Switch Control and Voice Control beyond the labels; colour perception for colour-blind users beyond the names and symbols; a physical device.

