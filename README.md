# FocusTimer

Multi-phase timer project. The `chrome/` subfolder contains a Chrome extension (Manifest V3) that runs a Focus timer, prompts to start Break, and handles pause/resume, notifications, and badge status. An iOS/Swift implementation can be added alongside later.

## Structure
- `chrome/` — Chrome extension source (Manifest V3) with popup, background, assets.
- `AGENTS.md` — repository guidelines/instructions.
- `plan.prompt.txt` — planning prompt reference.

## Chrome Extension (chrome/)
Features:
- Two-phase flow: Focus then Break, with confirmation between phases.
- Pause/Resume control and cancel/reset.
- Notifications on phase completion with action buttons.
- Badge color and tooltip indicate current phase/time remaining.
- State persists if the popup closes; alarms/heartbeat keep timers accurate.

Install/Run:
1) Go to `chrome://extensions` and enable Developer Mode.
2) Click "Load unpacked" and select the `chrome/` folder.
3) Configure durations in minutes, click Start. Use the pause (||/▶) and cancel (x) buttons as needed.

Notes:
- Notifications require browser/OS notification permission.
- The extension uses `chrome.storage`, `chrome.alarms`, and `chrome.notifications` permissions.

## Next steps
- Add iOS/Swift implementation alongside `chrome/`.
- Consider sharing logic/config across platforms.
