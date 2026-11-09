#!/bin/sh
# Makes each minute last fewer seconds in a Debug build on a simulator, for quick manual checks.
# Release builds ignore it. The app reads the value at launch, so relaunch it afterwards.
# Usage: scripts/debug-minute.sh <seconds 1-60 | off> [device name or UDID, default: booted]
set -u

bundle=com.ebochkarev.FocusTimer
key=debugSecondsPerMinute
value=${1:-}
device=${2:-booted}

case $value in
    off) ;;
    '' | *[!0-9]*)
        echo "Usage: scripts/debug-minute.sh <seconds 1-60 | off> [device]" >&2
        exit 2
        ;;
    *)
        if [ "$value" -lt 1 ] || [ "$value" -gt 60 ]; then
            echo "Seconds must be 1 to 60." >&2
            exit 2
        fi
        ;;
esac

if ! container=$(xcrun simctl get_app_container "$device" "$bundle" data 2>/dev/null); then
    echo "FocusTimer is not installed on '$device', or no simulator is booted. Run it from Xcode once." >&2
    exit 1
fi
domain="$container/Library/Preferences/$bundle"

if [ "$value" = off ]; then
    xcrun simctl spawn "$device" defaults delete "$domain" "$key" 2>/dev/null
    echo "Short minutes are off: a minute lasts 60 seconds. Relaunch the app."
else
    xcrun simctl spawn "$device" defaults write "$domain" "$key" -int "$value" || exit 1
    saved=$(xcrun simctl spawn "$device" defaults read "$domain" "$key" 2>/dev/null)
    if [ "$saved" != "$value" ]; then
        echo "FAILED: read back '$saved' instead of $value." >&2
        exit 1
    fi
    echo "A minute now lasts $value seconds in Debug builds on '$device'. Relaunch the app."
fi
