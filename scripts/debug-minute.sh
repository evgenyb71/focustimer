#!/bin/sh
# Makes each minute last fewer seconds in a Debug build on a simulator, for quick manual checks.
# Release builds ignore it. The app reads the value at launch, so relaunch it afterwards.
# Usage: scripts/debug-minute.sh <seconds 1-60 | off> [device name or UDID, default: booted]
set -u

bundle=com.ebochkarev.FocusTimer
key=debugSecondsPerMinute
value=${1:-}
device=${2:-booted}

# Only plain whole numbers 1-60 (no sign, no leading zero) or "off"; matched as text, so no arithmetic can fail.
case $value in
    off | [1-9] | [1-5][0-9] | 60) ;;
    *)
        echo "Usage: scripts/debug-minute.sh <seconds 1-60 | off> [device]" >&2
        exit 2
        ;;
esac

if ! container=$(xcrun simctl get_app_container "$device" "$bundle" data 2>/dev/null); then
    echo "FocusTimer is not installed on '$device', or no simulator is booted. Run it from Xcode once." >&2
    exit 1
fi
domain="$container/Library/Preferences/$bundle"

# "off" stores 60, which the app treats as real minutes. Writing and reading back a value makes success
# unambiguous: a failed read can never be mistaken for a cleared setting.
seconds=$value
[ "$value" = off ] && seconds=60

if ! xcrun simctl spawn "$device" defaults write "$domain" "$key" -int "$seconds" 2>/dev/null; then
    echo "FAILED: could not write the setting on '$device'; it is unchanged." >&2
    exit 1
fi
saved=$(xcrun simctl spawn "$device" defaults read "$domain" "$key" 2>/dev/null)
if [ "$saved" != "$seconds" ]; then
    echo "FAILED: read back '$saved' instead of $seconds." >&2
    exit 1
fi

if [ "$value" = off ]; then
    echo "Short minutes are off: a minute lasts 60 seconds. Relaunch the app."
else
    echo "A minute now lasts $seconds seconds in Debug builds on '$device'. Relaunch the app."
fi
