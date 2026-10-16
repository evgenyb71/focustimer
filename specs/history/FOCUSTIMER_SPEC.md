# FocusTimer Product and Technical Specification

Status: reconstruction of the existing FocusTimer for Chrome implementation, intended as the baseline specification for a future project.

## 1. Product summary

FocusTimer is a small two-phase timer for Chrome. A user configures a Focus duration and a Break duration, starts Focus, explicitly confirms when they are ready to begin Break, and is notified when each phase completes.

The core product promise is that timing remains correct while the extension popup is closed and after the Manifest V3 service worker is suspended or restarted. The popup is a controller and live display; the background service worker owns the authoritative state and deadlines.

## 2. Current implementation status

The Chrome extension in `chrome/` is the implemented baseline. It is a Manifest V3 extension, version `0.1.0`, with no build step or external dependencies.

Implemented:

- Configurable Focus and Break durations.
- Sequential Focus -> confirmation -> Break flow.
- Popup countdown refreshed once per second while open.
- Pause/resume for either running phase.
- Cancel/reset from any state.
- Persistent configuration and runtime state in `chrome.storage.local`.
- Deadline alarms plus a periodic heartbeat for recovery and badge refresh.
- Completion notifications.
- Toolbar badge color and tooltip reflecting the current phase.
- Recovery when the service worker initializes after a deadline has passed.

Not implemented or incomplete compared with the original planning prompt:

- The final Break notification does not have `Done` and `Restart` buttons.
- Restarting a complete cycle from the notification is not implemented.
- Focus notification declares an `OK` button, but its visible text/message also refers to Break; the wording is inconsistent.
- Notification sound relies on Chrome/OS default notification behavior; there is no custom sound asset.
- There are no meaningful automated tests.
- There is no Chrome Web Store packaging, publishing, privacy, or release workflow.
- The popup includes a hidden developer shortcut: entering `333` Focus minutes runs Focus for five seconds. This must not ship in a production rewrite.

## 3. User experience

### 3.1 Ready state

The popup displays:

- Title: `Focus / Break Timer`.
- Subtitle: `Run Focus, confirm, then run Break.`
- Focus duration input in minutes.
- Break duration input in minutes.
- Status `Ready` and time `--:--`.
- Primary `Start` button.
- Cancel icon in the header; pause is hidden.

Default configuration is one minute for each phase in the Chrome implementation. Values are persisted after a sequence starts. The future product should choose intentional defaults based on the desired workflow.

### 3.2 Starting Focus

When Start is clicked:

1. Both inputs must parse as positive minute values.
2. Minutes are converted to whole seconds.
3. The popup sends a `start` request with both durations.
4. The service worker accepts it only while idle, saves the configuration, creates an absolute Focus deadline, persists the new state, and schedules an alarm.
5. Inputs and Start become unavailable; pause becomes visible.
6. The popup shows `Focus Timer running` and the remaining `MM:SS`.

Although the HTML inputs use `min="1"` and `step="1"`, the JavaScript currently accepts positive decimal minutes. The future specification should make this explicit: either support decimal minutes consistently for testing/accessibility, or enforce whole minutes in both UI and validation.

### 3.3 Focus completion and confirmation

At the Focus deadline:

- State changes to `waitingForAConfirm`.
- The phase alarm is cleared/consumed and the deadline is removed.
- A persistent Chrome notification is shown with an OK button.
- The toolbar badge changes to the waiting color.
- If the popup is open, it shows `Focus Timer complete`, `00:00`, and `Start Break`.

Break begins only after either:

- the user clicks Start Break in the popup, or
- the user clicks the notification's first button.

Clicking the notification body itself has no implemented behavior.

### 3.4 Running Break

Starting Break loads the saved configuration, creates a new absolute deadline, enters `runningB`, persists state, and schedules the phase alarm. The popup shows the Break countdown and enables pause/cancel in the same way as Focus.

### 3.5 Break completion

At the Break deadline, the existing implementation immediately resets state to idle and then shows a persistent `Break Timer complete` notification with `Sequence finished.`

The future project should implement the originally intended completion decision:

- `Done`: reset to ready/idle.
- `Restart`: start Focus again using the last saved durations.

To support that decision reliably, the future state machine should enter a distinct `completed` state until the user chooses an action, rather than resetting before the notification interaction.

### 3.6 Pause, resume, and cancel

Pause is valid only during a running Focus or Break phase. It computes `remainingSeconds` from the deadline, rounds upward, clamps to at least one second, clears the phase alarm, removes the deadline, and persists `paused: true`.

Resume creates a new deadline from the stored remaining duration, clears the paused fields, reschedules the alarm, and ensures the heartbeat exists.

Cancel is currently accepted from any state. It clears the phase alarm and returns to idle. It does not erase the saved configuration and does not clear already displayed notifications.

## 4. State machine

Current states:

| State | Meaning | Allowed user actions | Automatic transition |
|---|---|---|---|
| `idle` | Ready to configure and start | Start, cancel | None |
| `runningA` | Focus deadline active or Focus paused | Pause/resume, cancel | Deadline -> `waitingForAConfirm` |
| `waitingForAConfirm` | Focus complete; waiting to begin Break | Start Break, cancel | None |
| `runningB` | Break deadline active or Break paused | Pause/resume, cancel | Deadline -> `idle` |

Paused status is represented as a Boolean on `runningA`/`runningB`, not as separate phases.

Recommended future states:

| State | Transition events |
|---|---|
| `idle` | `START` -> `focusRunning` |
| `focusRunning` | `PAUSE` -> `focusPaused`; `FOCUS_ELAPSED` -> `awaitingBreak`; `CANCEL` -> `idle` |
| `focusPaused` | `RESUME` -> `focusRunning`; `CANCEL` -> `idle` |
| `awaitingBreak` | `START_BREAK` -> `breakRunning`; `CANCEL` -> `idle` |
| `breakRunning` | `PAUSE` -> `breakPaused`; `BREAK_ELAPSED` -> `completed`; `CANCEL` -> `idle` |
| `breakPaused` | `RESUME` -> `breakRunning`; `CANCEL` -> `idle` |
| `completed` | `DONE` -> `idle`; `RESTART` -> `focusRunning`; `CANCEL` -> `idle` |

All transitions should be centralized, validated against the current state, and idempotent so duplicate messages, alarms, or notification clicks cannot start multiple phases.

## 5. Data model

Current local storage contains two top-level records:

```json
{
  "config": {
    "durationASeconds": 60,
    "durationBSeconds": 60
  },
  "state": {
    "phase": "idle",
    "endTimestamp": null,
    "paused": false,
    "remainingSeconds": null
  }
}
```

Rules:

- `endTimestamp` is Unix time in milliseconds and is authoritative while running.
- `remainingSeconds` is authoritative only while paused.
- A running, unpaused phase must have an `endTimestamp`.
- A paused phase must have positive `remainingSeconds` and no deadline.
- Waiting, completed, and idle states must have neither a deadline nor paused time.
- Configuration survives reset and is reused for Break and future restart behavior.

Recommended future additions:

- `schemaVersion` for migrations.
- A unique `cycleId` or monotonically increasing transition version to reject stale events.
- `updatedAt` for diagnostics and conflict resolution.
- Explicit phase names (`focusRunning`, `breakRunning`) instead of A/B names.
- Notification IDs stored or deterministically derived from the cycle and phase.

## 6. Chrome architecture

### 6.1 Manifest

Manifest V3 declares:

- Popup: `src/popup.html`.
- Background service worker: `src/background.js`.
- Permissions: `alarms`, `notifications`, and `storage`.
- One PNG reused for all icon sizes.

No host permissions, content scripts, remote code, analytics, or network access are used.

### 6.2 Background service worker

The service worker is the single source of truth. It:

- validates commands from the popup;
- reads and writes configuration/state;
- computes absolute deadlines;
- creates and clears Chrome alarms;
- handles phase completion;
- creates notifications;
- handles notification button clicks;
- updates toolbar badge/title state;
- broadcasts `stateChanged` messages when state changes;
- restores alarms and reconciles overdue phases on initialization.

Supported popup messages are `start`, `ackA`, `pause`, `resume`, and `cancel`. Responses use `{ ok: true }` or `{ ok: false, error }`.

### 6.3 Popup

The popup is intentionally stateless between openings. On load and on every storage change it reads `config` and `state`, renders the correct controls, and derives the visible countdown from the stored deadline. A local one-second interval updates only the display; it never owns phase completion.

The service worker broadcasts `stateChanged`, but the popup does not listen to runtime messages. It instead listens to `chrome.storage.onChanged`, making the runtime broadcast redundant in the current implementation.

### 6.4 Timing and recovery

Two alarms are used:

- `phaseEnd`: one-shot alarm at the current phase deadline.
- `heartbeat`: repeating alarm every minute.

The one-shot alarm performs normal completion. The heartbeat updates the toolbar title and catches an overdue phase if the original alarm was delayed. Initialization also checks an overdue deadline and restores a missing one-shot alarm.

The design deliberately uses timestamps rather than decrementing a counter in the service worker. This makes the displayed and recovered time correct across popup closure, worker suspension, and browser/device sleep.

## 7. Toolbar and notifications

The toolbar badge uses a blank visible badge as a colored status dot:

- Idle: badge hidden; neutral color defined but not shown.
- Focus: teal (`#2a6f6b`).
- Waiting for Break: orange (`#d38400`).
- Break: blue (`#3b5998`).
- Paused: gray (`#999999`).

The action tooltip displays idle, waiting, paused, or approximate remaining time. Because it is updated on state changes and the one-minute heartbeat, its countdown is not second-accurate while the popup is closed.

Notifications use `requireInteraction: true`, priority 2, the extension icon, default sound behavior, and no explicit cleanup. The future project should use stable notification IDs and clear or replace stale notifications on cancel, restart, or state transition.

## 8. Visual design baseline

The popup is fixed at 320 px wide and uses a warm paper-like palette, serif typography, rounded cards, light borders, and a teal primary action. Its layout consists of a header, a configuration card, a status card, and a full-width primary button.

Accessibility and polish work remaining:

- Replace text glyphs `||`, `x`, and `▶` with accessible icons and explicit `aria-label`s.
- Ensure keyboard focus styles are visible.
- Verify contrast and Windows/Linux font fallbacks.
- Avoid using badge color as the only phase signal.
- Decide whether cancel needs confirmation while a timer is active.
- Display validation errors consistently with accepted decimal/integer rules.
- Provide notification-permission guidance when notifications are blocked.

## 9. Edge cases and required behavior

- Rapid Start clicks: only the first request in idle may succeed.
- Duplicate alarms: completion must be harmless if the state has already advanced.
- Stale notification click: ignore it unless its cycle and expected state still match.
- Popup closed: timing and transitions continue in the service worker.
- Service worker restart: restore the phase alarm or immediately reconcile an overdue deadline.
- Browser/device sleep: compute remaining time from the deadline; do not replay every missed tick.
- Pause near zero: current behavior preserves at least one second. Future behavior should define whether an already elapsed phase completes instead.
- Cancel while waiting: return to idle and invalidate the Focus notification action.
- Cancel while paused: discard remaining time and return to idle.
- Storage corruption or partial old state: validate/migrate and fall back safely to idle without losing a valid configuration.
- System clock change: wall-clock deadlines can jump. This is acceptable for the current implementation but should be documented and tested.
- Notification permission denied: timer flow must still complete and the toolbar/popup must remain usable.
- Browser startup after a long absence: perform exactly one valid transition based on persisted state, then notify appropriately.
- Extension update: preserve compatible configuration and migrate state by schema version.

## 10. Testing specification

There are currently no Chrome tests. A future implementation should add:

- Unit tests for validation, time formatting, remaining-time calculation, and every state transition.
- Fake-clock tests for pause/resume, exact deadlines, delayed alarms, sleep, and initialization recovery.
- Tests proving duplicate commands/alarms and stale notification actions are idempotent.
- Storage migration and corrupt-state recovery tests.
- Popup tests for every state, disabled controls, validation, and storage-driven rerendering.
- Integration tests with mocked Chrome APIs for storage, alarms, notifications, and action badge/title.
- Manual browser checks for popup closure, service-worker suspension, browser restart, notification permissions, and OS notification behavior.

Acceptance criteria for the core flow:

1. The user can configure valid Focus and Break durations and start exactly one cycle.
2. Focus remains time-correct with the popup closed.
3. Focus completion produces a visible in-extension state and, when permitted, a system notification.
4. Break never starts without explicit confirmation.
5. Either running phase can be paused, the browser can remain closed/suspended, and resume continues from the saved duration.
6. Break completion offers Done and Restart; Restart uses the saved configuration.
7. Cancel always returns to a clean ready state and invalidates pending alarms/actions.
8. Browser sleep, restart, worker restart, and duplicate events never create overlapping cycles.

## 11. Build, installation, and delivery

Current local installation:

1. Open `chrome://extensions`.
2. Enable Developer mode.
3. Choose Load unpacked.
4. Select the repository's `chrome/` directory.

There is currently no compilation step. A future project should keep the dependency footprint small, but add repeatable lint/test/package scripts and document them in the root README and repository guidelines. Store-ready delivery also requires correctly sized icons, a privacy disclosure, screenshots, versioning/release notes, and verification against the current Chrome Web Store policies.

## 12. Future implementation priorities

1. Extract a pure, tested state-transition layer from Chrome API side effects.
2. Add the `completed` state and implement Done/Restart notification actions.
3. Add event/cycle versioning and deterministic notification cleanup.
4. Remove the `333` developer shortcut and settle duration/default rules.
5. Add automated tests with a fake clock and mocked Chrome APIs.
6. Improve accessibility, permission/error feedback, and icons.
7. Add packaging and release documentation.
