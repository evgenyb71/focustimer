# Chrome tech stack

Status: as implemented at `6e00429`, reviewed 2026-10-16. No stack changes planned.

| Area | Existing choice |
| --- | --- |
| Platform | Chrome extension, Manifest V3, version 0.1.0 |
| UI | Plain HTML, CSS, and JavaScript in `chrome/src/popup.*` |
| State owner | JavaScript service worker in `chrome/src/background.js` |
| Persistence | `chrome.storage.local`, records `config` and `state` |
| Timing | Unix-millisecond deadlines, one-shot `phaseEnd` alarm, one-minute `heartbeat` alarm |
| Notifications | `chrome.notifications`, OS/default sound behavior, no custom sound asset |
| Toolbar | `chrome.action` badge and title |
| Permissions | `alarms`, `notifications`, `storage`; no host permissions or content scripts |
| Assets | `chrome/assets/icon128.png` reused for declared sizes |
| Tooling | No dependencies, build step, test runner, or packaging pipeline |

## Architecture and persistence

The worker handles commands `start`, `ackA`, `pause`, `resume`, and `cancel`, updates storage, schedules alarms, and handles completion. Initialization reconciles overdue deadlines; the heartbeat provides additional recovery and toolbar updates. These paths exist in source; reliability under all race and lifecycle conditions is not proven.

The popup reads storage and listens to `chrome.storage.onChanged`. Its one-second interval only renders time. The worker's `stateChanged` runtime broadcasts have no popup listener.

Configuration stores `durationASeconds` and `durationBSeconds`. Runtime state uses `phase`, `endTimestamp`, `paused`, and `remainingSeconds`; the waiting transition stores only phase and a null deadline. Persisted data is unversioned. No cross-device data sharing exists.

## Local use and verification

Open `chrome://extensions`, enable Developer mode, choose Load unpacked, and select `chrome/`. There is no `npm` build or test command. Historical review is based on source and Git history; this documentation migration does not claim fresh browser tests or Chrome Web Store readiness.

For any separately authorized future change, manual checks should cover the full flow, popup closure, worker restart, pause/resume, cancel, denied notifications, and browser/device sleep.

## References

[Mission](mission.md), [retrospective roadmap](roadmap.md), [archived technical specification](../history/FOCUSTIMER_SPEC.md).
