#!/bin/sh
# Runs the unit tests and fails unless the build succeeds, tests ran, and none failed.
# Usage: scripts/test.sh [device name] [iOS version]
set -u

device=${1:-iPhone 17 Pro}
os=${2:-26.5}
cd "$(dirname "$0")/.." || exit 1

stamp=$(date +%Y%m%d-%H%M%S)
bundle=/tmp/FocusTimerTests-$stamp.xcresult
log=/tmp/FocusTimerTests-$stamp.log
summary=/tmp/FocusTimerTests-$stamp.json

xcodebuild -project ios/FocusTimer/FocusTimer.xcodeproj -scheme FocusTimer \
    -destination "platform=iOS Simulator,name=$device,OS=$os" \
    -derivedDataPath /tmp/FocusTimerDerivedData -resultBundlePath "$bundle" \
    CODE_SIGNING_ALLOWED=NO test >"$log" 2>&1
status=$?

if ! xcrun xcresulttool get test-results summary --path "$bundle" >"$summary" 2>/dev/null; then
    grep -E ": error:|\*\* TEST" "$log" | tail -20
    echo "FAILED: no test results (xcodebuild exit $status). Log: $log"
    exit 1
fi

count() {
    plutil -extract "$1" raw -o - "$summary" 2>/dev/null
}

total=$(count totalTestCount)
passed=$(count passedTests)
failed=$(count failedTests)
skipped=$(count skippedTests)
expected=$(count expectedFailures)

for value in "$total" "$passed" "$failed" "$skipped" "$expected"; do
    case $value in
        '' | *[!0-9]*)
            echo "FAILED: unreadable test counts in $summary. Log: $log"
            exit 1
            ;;
    esac
done

echo "$device, iOS $os: total $total, passed $passed, failed $failed, skipped $skipped, expected failures $expected"
echo "Result bundle: $bundle"

if [ "$status" -ne 0 ] || [ "$failed" -ne 0 ]; then
    grep -E ": error:|\*\* TEST" "$log" | tail -20
    echo "FAILED: xcodebuild exit $status. Log: $log"
    exit 1
fi
if [ $((passed + expected)) -eq 0 ]; then
    echo "FAILED: no tests ran. Log: $log"
    exit 1
fi
echo "PASSED"
