# FocusTimer

FocusTimer is an offline Focus → confirmation → Break timer. The native iPhone app is actively developed; the Chrome extension is a frozen retrospective baseline. Development follows the platform mission, roadmap, and one phase spec at a time.

| Platform | Mission | Tech stack and local run | Roadmap |
| --- | --- | --- | --- |
| Chrome | [Mission](specs/chrome/mission.md) | [Stack](specs/chrome/tech-stack.md) | [Retrospective](specs/chrome/roadmap.md) |
| iOS | [Mission](specs/ios/mission.md) | [Stack](specs/ios/tech-stack.md) | [Phases](specs/ios/roadmap.md) |

Start with the relevant mission and follow [AGENTS.md](AGENTS.md) for the working agreement. The next planned work is [Stage 2: Guided Break](specs/ios/roadmap.md#stage-2-guided-break), beginning with I36 product and interaction design. Guided Break is not built yet. Detailed choices are agreed in the phase that needs them, before implementation.

An automated accessibility audit runs as UI tests (`scripts/test.sh --ui`), with one open contrast exception recorded in [I28](specs/ios/phases/I28-accessibility-audit.md). Release notes are planned, not yet written.

## Source and local use

- `chrome/`: plain Manifest V3 extension. In `chrome://extensions`, enable Developer mode, choose Load unpacked, and select this directory. No build step.
- `ios/FocusTimer/`: Swift 6 / SwiftUI, iPhone portrait, iOS 26+. Open `ios/FocusTimer/FocusTimer.xcodeproj` in Xcode 26.5 or later, choose an iPhone simulator and Run. See [AGENTS.md](AGENTS.md#build-and-verification) for the command-line build and tests.
- `specs/`: platform missions, tech stacks, roadmaps, phase specs, and historical references.
- [CHANGELOG.md](CHANGELOG.md): dated change history.

## Original documents

The four originals are preserved unchanged in `specs/history/` for provenance. Their embedded prompts, proposed features, stale paths, and status claims are historical references; use the active missions and [working agreement](AGENTS.md) for new work.

- [Original README](specs/history/README.md)
- [Original Chrome planning prompt](specs/history/plan.prompt.txt)
- [Reconstructed product and technical specification](specs/history/FOCUSTIMER_SPEC.md)
- [Original iPhone implementation status](specs/history/focustimer_ios_spec.md)
