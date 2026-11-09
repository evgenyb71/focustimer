# I26 Add debug-only short durations for manual checks

Status: verified

## Goal

Manual checks at one-minute durations take a long time ([I16](I16-notification-done.md) needed five full cycles). In a Debug build, a stored setting can make each minute last fewer seconds, for example 10. Durations still read "1 min", and alerts arrive at the shortened time. Release builds contain none of this. This phase comes before I17, whose checks also cover several paths.

Roadmap exit check: Debug builds can run a minute as fewer seconds, guarded by `#if DEBUG`, so manual checks finish quickly; Release builds contain none of it. Steppers, saved durations, bounds, and the saved format stay in minutes. Unit tests keep real lengths and cover the shortened case; a user-reported manual run confirms alerts arrive at the shortened time.

## Decisions

User, 2026-11-09:

- **A stored setting, off by default:** `#if DEBUG` code reads a seconds-per-minute value at launch and uses 60 when it is unset. Normal Debug runs and the unit tests stay real. A small script sets or clears it on the booted simulator, and it survives home-screen launches.
- **No indicator:** the screen looks the same; only the countdown shows the shorter time.
- **Checks:** Cmd+U and a short manual run.

Agent decisions, open to revision:

- **Model:** the store takes a seconds-per-minute value when it is created, 60 by default. A phase runs for its configured whole minutes times that value. It applies wherever a duration becomes a run length: starting a phase, the deadline cap after a backward clock jump, and the paused-time clamp at launch. Configuration, Steppers, bounds, and saved values do not change.
- **Setting:** an integer `debugSecondsPerMinute` in the app's own defaults. A missing value, or one outside 1–60, means 60. The app reads it once, when the shared store is created, so a change applies from the next launch. Release builds compile neither the reading code nor the key.
- **Script:** `scripts/debug-minute.sh <seconds|off> [device]` writes the value in the installed app's container on the booted simulator, reads it back, and says to relaunch the app. `off` writes 60, which the app treats as real minutes, so every run ends in a verified write; see the review below. It changes no project setting, scheme, or signing.
- **Switching during a phase:** a deadline started with real minutes is longer than the shortened length, so the next launch caps it without a notice, as after a backward clock jump; a paused time is clamped with the correction notice. Debug only, and acceptable for a testing aid.
- **Alerts:** they are scheduled from the deadline, so they follow the shortened length with no change.

## Non-goals

- Any visible change, Release behavior change, or user-facing setting.
- Changing defaults, bounds, whole-minute steps, or the saved format.
- Automating the manual checks (the UI-test target stays reserved).

## Plan

Tick an item only when it is done.

- [x] Give the store a seconds-per-minute value, 60 by default, and use it for starting a phase, the deadline cap, and the paused-time clamp.
- [x] Read `debugSecondsPerMinute` under `#if DEBUG` when the shared store is created, ignoring missing and out-of-range values.
- [x] Add `scripts/debug-minute.sh` to set or clear the value on the booted simulator.
- [x] Add the Swift Testing tests listed under Checks.
- [x] Run `scripts/test.sh` and record the output in Results.
- [x] Build the Release configuration and confirm the binary does not contain the setting's key.
- [x] Try the script on the agent simulator: set, launch, read back, clear.
- [x] User: run Cmd+U and the manual run; record both in Results as user-reported.
- [x] Document the script in [AGENTS.md](../../../AGENTS.md#build-and-verification) and the [tech stack](../tech-stack.md).
- [x] Set `Status: verified` and move the roadmap row to Completed.
- [x] Open the PR; fix correctness findings from the Codex review and rerun the affected checks.

## Checks

Agent-run: `scripts/test.sh`, with Swift Testing tests covering:

- With the default value, starting Focus and Break gives deadlines at the configured minutes times 60, as before.
- With 10 seconds per minute, a 1-minute Focus and a 2-minute Break end after 10 and 20 seconds, and their alerts are scheduled at those deadlines.
- The Steppers' configuration and the saved configuration stay in whole minutes with a shortened minute.
- With a shortened minute, pausing keeps the remaining shortened time; the deadline cap and the paused clamp use the shortened length.
- A deadline started with real minutes is capped to the shortened length at the next launch, without a notice.
- The setting's value is used only from 1 to 60; missing, 0, negative, and larger values give 60.

Agent-run, outside the tests: a Release build succeeds and its binary does not contain `debugSecondsPerMinute`. The script sets, reads back, and turns off the value on the agent simulator.

User-reported, in Xcode on the iPhone 18 Pro Max simulator (iOS 27.0):

- Cmd+U passes; report the summary line with the count.
- Manual run, notifications allowed, Focus and Break at 1 min:
  1. Run the app from Xcode once, then stop it. Run `scripts/debug-minute.sh 10`, and open the app from its home screen icon.
  2. Press Start: the Stepper still shows 1 min, and the countdown starts at 00:10. Go to the home screen: the Focus alert arrives after about 10 seconds.
  3. Open the app, press Start Break, and go to the home screen: the Break alert arrives after about 10 seconds. Press Done on it.
  4. Run the app from Xcode again: a Focus still lasts about 10 seconds.
  5. Run `scripts/debug-minute.sh off`, stop the app, and open it from the icon: a Focus starts at 01:00.

Stays unverified: a Release build on a physical device; the setting on a physical device, which the script does not support.

## Results

Agent-run, 2026-11-09, `scripts/test.sh` on iPhone 17 Pro, iOS 26.5:

```text
iPhone 17 Pro, iOS 26.5: total 203, passed 203, failed 0, skipped 0, expected failures 0
PASSED
```

That is the earlier 195 plus 8 new test functions in `TimerStoreShortMinuteTests`; the count treats a parameterized test as one. No existing test changed, which shows the default of 60 keeps every earlier length. The build log shows no warnings from the project's files. A missing setting reads as 0 from `UserDefaults`, which the out-of-range test covers.

Agent-run Release check: Release and Debug simulator builds both succeeded. `strings` found `debugSecondsPerMinute` 0 times in the Release app and 2 times in the Debug app, which shows the search works.

Agent-run script and app check, on iPhone 17 Pro, iOS 26.5:

- The script rejected no value, `abc`, `0`, `61`, and `-5`, each with exit code 2.
- `scripts/debug-minute.sh 10` wrote and read back the value. After a relaunch, Start ran a 1-minute Focus that showed 00:01 within seconds while the Stepper still read 1 min. The Focus alert then arrived, with the I16 wording, and the screen showed "Focus complete".
- `scripts/debug-minute.sh off` removed the value; reading it afterwards reported that it does not exist. After a relaunch, a 1-minute Focus showed 00:55 a few seconds after Start.
- The agent shut down its simulator afterwards.

User-reported, 2026-11-09: Cmd+U and all five steps of the manual run passed ("All pass"). The Cmd+U summary line with the count, the individual steps, and the simulator were not reported.

Remaining limitations: a Release build on a physical device; the setting on a physical device, which the script does not support.

### Review

Codex review, posted on the PR, 2026-11-09, with its own `scripts/test.sh` run at total 203, passed 203, failed 0. It found no problems in the Swift code and two in the script:

- **[P2] Report failures when clearing short minutes.** Fixed. `off` hid the error from `defaults delete` and always reported success, so a failed clear could leave short minutes on for the next check. It now reads the value back after the delete and fails if the value is still there. An already-absent value still counts as cleared.
- **[P3] Validate the numeric input before writing.** Fixed. An overlong number made both shell comparisons error out and fall through to the write, and `010` was written and then failed the read-back. The script now matches only plain 1–60 as text, before any write.

Agent-run after the fixes:

- With a stand-in `xcrun`: no value, `abc`, `0`, `00`, `010`, `61`, `99`, `-5`, `+5`, ` 5`, and a 20-digit number each exit 2 and write nothing. 1, 9, 10, 59, and 60 are written as given. `off` clears a set value and succeeds when already off. A failed delete while the value is set exits 1, with "the setting is still 10". The old script, given the same failed delete, reported success with exit 0.
- On iPhone 17 Pro, iOS 26.5: set 10, `off`, `off` again, and `010` gave exit codes 0, 0, 0, and 2.
- No Swift changed, so the 203-test result stands. The user's manual run is not affected: it used only valid values and a successful `off`.

Codex re-review, posted on the PR, 2026-11-09: the numeric finding is resolved, but one P2 remained.

- **[P2] A failed read-back still looks like a successful clear.** Fixed. If the simulator shut down after the container lookup, both the delete and the read failed, and the failed read passed for a cleared setting. Codex reproduced this with a mocked lookup. Following its suggestion, `off` now writes 60 and reads it back, the same path as any other value, so the setting stays stored at 60 instead of being removed. The app treats 60 as real minutes, and the Swift tests already cover 60.

Agent-run after the fix:

- With the stand-in `xcrun`, which can now fail every simulator command, the write, or the read: the 11 invalid inputs still exit 2 and write nothing, and 1–60 are written as given. `off` stores 60 whether short minutes were on, never set, or already off. While set to 10, `off` and `20` each exit 1 when every simulator command fails, when the write fails, or when the read fails; a failed write leaves the value unchanged. The previous version, with every simulator command failing, reported success with exit 0.
- On iPhone 17 Pro, iOS 26.5: set 10 and `off` gave exit 0, and the stored value read back as 60. `off` again gave exit 0. After the simulator was shut down, `off` gave exit 1.
- No Swift changed, so the 203-test result stands.
