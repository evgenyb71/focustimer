# Chrome mission

Status: retrospective baseline, reviewed 2026-10-16 against commit `6e00429`. Implementation is frozen for this initiative. “Implemented” means present in source, not newly runtime-tested.

## Purpose

Provide a small, offline two-phase timer: configure Focus and Break, start Focus, explicitly confirm the start of Break, and receive completion notifications. Preserve timing when the popup closes or the Manifest V3 worker is suspended.

## Implemented contract

- Focus and Break default to 60 seconds each. The popup accepts positive minute values, including decimals, and converts to rounded seconds; the worker rejects durations below one second.
- Flow: `idle → runningA → waitingForAConfirm → runningB → idle`. Break starts only through Start Break or the Focus notification's first action button.
- Pause/resume works during either running phase. Cancel returns to idle and retains configuration. Duration inputs are unavailable outside idle.
- Persist configuration and runtime state locally. Deadlines drive running time; saved remaining seconds drive paused time. Popup ticks update the display, not authoritative state.
- Use system notifications, badge color, and tooltip text to communicate phase status. Notifications depend on browser/OS permission and behavior.
- Keep the warm card-based popup and small dependency footprint.

## Recorded limitations

Break completion immediately returns to idle: there is no completed state, Done/Restart choice, or cycle restart action. Focus notification text says “Click Break” while its button says “OK”. Notification actions are not scoped to a cycle or notification ID, and displayed notifications are not cleaned up on cancel. Rapid asynchronous commands have no explicit serialization guarantee.

The hidden `333`-minute Focus input runs for five seconds. Decimal acceptance differs from whole-minute HTML controls and rounded configuration rendering. Pause at an elapsed deadline preserves at least one second. Storage has no schema migration or robust validation. Wall-clock changes can affect deadlines. Accessibility, store packaging, and meaningful automated tests are incomplete.

These are historical gaps, not an authorized Chrome backlog. The original prompt's Done/Restart and other future recommendations must not be mistaken for delivered behavior.

## Scope boundary

No Chrome application code changes, dependency changes, refactoring, fixes, or publishing are planned here. No accounts, analytics, cloud storage, network service, or shared runtime with iOS. A future Chrome change requires an explicit scope decision and revised specification.

## References

- [Stack](tech-stack.md) and [retrospective roadmap](roadmap.md).
- [Reconstructed specification](../history/FOCUSTIMER_SPEC.md), [original planning prompt](../history/plan.prompt.txt), and [original README](../history/README.md). These are historical sources, not current instructions.
