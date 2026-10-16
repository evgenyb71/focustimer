# FocusTimer

Offline Focus → confirmation → Break timers for Chrome and iPhone. This repository uses spec driven development. Chrome is a frozen retrospective baseline; iOS is the active development platform. This documentation migration changes no application code.

| Platform | Mission | Tech stack and local run | Roadmap |
| --- | --- | --- | --- |
| Chrome | [Mission](specs/chrome/mission.md) | [Stack](specs/chrome/tech-stack.md) | [Retrospective](specs/chrome/roadmap.md) |
| iOS | [Mission](specs/ios/mission.md) | [Stack](specs/ios/tech-stack.md) | [Small implementation phases](specs/ios/roadmap.md) |

Start with the relevant constitution, then specify one small phase with acceptance checks before implementation. Follow [AGENTS.md](AGENTS.md) for the working agreement. Done/Restart and other roadmap capabilities are planned, not currently implemented.

## Source and local use

- `chrome/`: plain Manifest V3 extension. In `chrome://extensions`, enable Developer mode, choose Load unpacked, and select this directory. No build step.
- `ios/FocusTimer/`: Swift 6 / SwiftUI, iPhone portrait, iOS 26+. Open `ios/FocusTimer/FocusTimer.xcodeproj` in Xcode 26.5 or later, choose an iPhone simulator and Run. See the iOS stack for the CLI build command.
- `specs/`: active platform constitutions and future phase specs.
- [CHANGELOG.md](CHANGELOG.md): dated change history.

## Original documents

The four originals are preserved unchanged in `specs/history/` for provenance. Their embedded prompts, proposed features, stale paths, and status claims are historical references; the active constitutions govern new work.

- [Original README](specs/history/README.md)
- [Original Chrome planning prompt](specs/history/plan.prompt.txt)
- [Reconstructed product and technical specification](specs/history/FOCUSTIMER_SPEC.md)
- [Original iPhone implementation status](specs/history/focustimer_ios_spec.md)
