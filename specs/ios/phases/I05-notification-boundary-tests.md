# I05 Notification boundary and first unit-test target

Status: in progress (2026-10-20); plan group 1 (notification boundary) implemented and built, not committed. Implements roadmap phase I05 in the [iOS roadmap](../roadmap.md).

Context: [mission](../mission.md), [tech stack](../tech-stack.md), previous phase [I03-I04](I03-I04-inject-clock-and-store.md).

Roadmap exit check: a test double observes schedule and cancel calls; the test command is documented and run.

## Requirements

### Scope

- **Notification boundary:** introduce a small protocol for the three calls `TimerStore` makes today (schedule completion for a phase at a deadline, cancel the pending completion for a phase, cancel all pending completions). Inject it into `TimerStore`'s internal initializer like `Clock` and `KeyValueStore`; production uses a system implementation backed by the existing `NotificationScheduler` code.
- **Live clock fix:** the system implementation computes the trigger interval from the current time supplied by `TimerStore`'s injected `Clock`, not from `deadline.timeIntervalSinceNow`. This closes the limitation recorded in the [tech stack](../tech-stack.md) after I03-I04.
- **Test target:** add a unit-test target `FocusTimerTests`, hosted by the app, using Swift Testing. Add a small set of tests that construct `TimerStore` with a fake clock, an in-memory store, and a recording notification double, and assert the observed schedule and cancel calls.
- **Documentation:** record the exact `xcodebuild test` command and simulator destination in `AGENTS.md` and the [tech stack](../tech-stack.md); update their wording from "native XCTest targets" to say unit tests use Swift Testing and XCTest is reserved for UI tests.
- **Housekeeping:** replace "pending push" in the roadmap's I03-I04 completed row with `cb2b3aa` on `main` (deferred from I03-I04 close-out).

### Non-goals

- App delegate setup (`configureCategories`, `requestAuthorization`) and the notification response handler stay static and unchanged.
- Broad transition and deadline tests (I06); invariant validation (I07); cycle identity, stale actions, and delivered-notification cleanup (I10, I11).
- UI tests, performance tests, physical device, and the deferred I02 notification rows (N1 to N8).
- Any change to timer behavior, persisted keys, or notification content and identifiers.
- `chrome/`.

### Decisions

- Boundary shape: a protocol (working name `NotificationScheduling`) with a system implementation, matching the `Clock` and `KeyValueStore` style. `NotificationScheduler`'s existing code is reused or wrapped rather than rewritten; whether the enum becomes the conforming type or a thin wrapper is decided during implementation.
- The current time reaches the system implementation from `TimerStore` (for example, the schedule method also takes `now`), so the fake clock makes scheduled intervals deterministic. The exact signature is decided during implementation.
- Test framework: Swift Testing (`import Testing`, `@Test`, `#expect`) for unit tests; XCTest is reserved for a future UI-test target. Rationale: Apple's current direction, native Swift 6 concurrency and `@MainActor` support, parameterized tests for later phases. Test files keep the `*Tests.swift` naming.
- Target creation: the user adds `FocusTimerTests` in Xcode (File > New > Target > Unit Testing Bundle, hosted by FocusTimer, added to the FocusTimer scheme's test action). Xcode writes `project.pbxproj` and the scheme; the agent does not hand-edit them. The user may pick either testing system in the template; the agent rewrites the generated file to Swift Testing.
- Tests use `@testable import FocusTimer` and the internal initializer; each test builds its own fake clock, in-memory store, and notification double, so parallel execution does not share state.
- Validation: agent runs `xcodebuild test` and a short simulator flow check on the iPhone 17 Pro (iOS 26.5); the user runs the tests once with Cmd+U in Xcode, recorded as user-reported.

### Context from the current code

- `TimerStore` calls `NotificationScheduler.scheduleCompletion(for:at:)` in `startPhase` and on resume, `cancelPendingCompletion(for:)` on pause, and `cancelAllPendingCompletions()` in `cancel()`.
- `NotificationScheduler.scheduleCompletion` computes `max(1, deadline.timeIntervalSinceNow)` and uses stable identifiers `focusComplete` and `breakComplete`.
- Hosted tests launch the app, so `TimerStore.shared` and the app delegate's authorization request run in the host process; the tests' own `TimerStore` instances are separate and use only injected dependencies.
- The project uses file-system synchronized groups and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` for the app target; the test target's isolation settings are whatever the template produces unless they block compilation.

### Affected components

- `ios/FocusTimer/FocusTimer/NotificationScheduler.swift`: protocol, system implementation, clock-supplied interval.
- `ios/FocusTimer/FocusTimer/TimerStore.swift`: injected notification dependency; calls routed through it.
- New `ios/FocusTimer/FocusTimerTests/` (created by Xcode) with `*Tests.swift` files and test doubles.
- `ios/FocusTimer/FocusTimer.xcodeproj/project.pbxproj` and `xcshareddata/xcschemes/FocusTimer.xcscheme`: changed by Xcode when the user adds the target.
- `AGENTS.md`, [tech stack](../tech-stack.md): test command and framework wording. [Roadmap](../roadmap.md): I03-I04 commit reference, and I05 close-out.
- Unchanged: `FocusTimerApp.swift`, `ContentView.swift`, `Clock.swift`, `KeyValueStore.swift`.

### Invariants to preserve

Single authoritative timer state (`TimerStore.shared` stays the only production instance), explicit Break confirmation, local persistence (same keys and encoding), deadline-based recovery. Production notification behavior (identifiers, content, Focus category and OK action, pending removal on pause and cancel) stays the same.

## Plan

1. Notification boundary (agent, one commit)
   - [x] Add the notification protocol and system implementation; compute the interval from the supplied current time.
   - [x] Inject it into `TimerStore` with a production default; route the four calls through it.
   - [x] Build; confirm with `grep` that `TimerStore.swift` no longer references `NotificationScheduler.` directly and that the scheduler no longer uses `timeIntervalSinceNow`.
2. Test target (user, then agent)
   - [ ] User adds `FocusTimerTests` in Xcode as described in Decisions and reports done.
   - [ ] Agent inspects the generated target, scheme, and settings (deployment target 26.0, host app, test action) without editing project files.
3. First tests (agent, one commit with the target)
   - [ ] Add test doubles: fake clock, in-memory store, recording notification scheduler.
   - [ ] Add focused tests, for example: Start Focus schedules one Focus completion at now + Focus duration; Pause cancels the Focus completion; Resume schedules again at now + remaining; Cancel cancels all; Start Break after Focus expiry schedules one Break completion.
   - [ ] Run `xcodebuild test`; record the command, destination, and result.
4. Documentation and close-out (agent)
   - [ ] Add the test command and destination to `AGENTS.md` and the tech stack; update the framework wording.
   - [ ] Replace "pending push" in the roadmap's I03-I04 row with `cb2b3aa` on `main`.
   - [ ] Agent simulator flow check; record user Cmd+U result.
   - [ ] Set status to verified only with evidence; move I05 to the roadmap's completed table; the user runs `/update-changelog` before merging.

## Validation

### Agent-run

Toolchain checks as in `AGENTS.md`. Build after group 1:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FocusTimerDerivedData CODE_SIGNING_ALLOWED=NO build
```

Tests after group 3 (installed destination, not the user's booted device; exact command recorded in Results and documentation):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/FocusTimerDerivedData CODE_SIGNING_ALLOWED=NO test
```

Expected: build succeeds with no new compiler warnings; all tests pass; the recording double shows the expected schedule and cancel calls and deterministic deadlines from the fake clock.

Static checks: `TimerStore.swift` has no direct `NotificationScheduler.` calls; `NotificationScheduler.swift` has no `timeIntervalSinceNow`.

Agent simulator flow check (iPhone 17 Pro, iOS 26.5, one-minute durations): Start, Pause, Resume, Cancel behave as before; a Break run to expiry shows the "Break Timer complete" banner in the foreground, as observed in I03-I04.

### User-reported

Run the FocusTimer scheme's tests in Xcode (Product > Test, Cmd+U) on any iOS 26+ simulator; report pass or fail and the simulator used.

### Unverified after this phase

- Real notification delivery in the background, the OK action, and denied permission (deferred I02 N rows).
- Transition and deadline behavior beyond the schedule and cancel calls (I06).
- Physical device.

## Results

### Plan group 1: notification boundary (agent-run, 2026-10-20)

- Change in `NotificationScheduler.swift`: the `NotificationScheduler` enum keeps the identifiers, `configureCategories()`, and `requestAuthorization()` used by the app delegate. New `protocol NotificationScheduling` with `scheduleCompletion(for:at:now:)`, `cancelPendingCompletion(for:)`, and `cancelAllPendingCompletions()`. New `struct SystemNotificationScheduler` holds the former static schedule and cancel code unchanged except that the trigger interval is `max(1, deadline.timeIntervalSince(now))`. Identifiers, content, category, and pending-request removal are unchanged.
- Change in `TimerStore.swift`: `private let notifications: any NotificationScheduling`; initializer `init(clock:store:notifications:)` with default `SystemNotificationScheduler()`. `startPhase` and resume read `clock.now` once and pass it as `now`; pause and cancel call the injected scheduler.
- Build: Xcode 27.0, the Validation build command with `DEVELOPER_DIR`; `** BUILD SUCCEEDED **`. No compiler warnings; the same unrelated `appintentsmetadataprocessor` tool warning as earlier phases.
- Static checks: `TimerStore.swift` has no `NotificationScheduler.` references; no `timeIntervalSinceNow` remains in any app source file; no static schedule or cancel callers remain.
- Not yet run: tests (target not added), simulator flow check.
