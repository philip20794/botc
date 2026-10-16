#!/usr/bin/env bash

# android-emulator-runner executes its `script` input line by line. Keep shell
# functions, traps, and pipelines in this Bash file instead.
set -uo pipefail

logs_dir='build/android-e2e-logs'
if ! mkdir -p "$logs_dir"; then
  echo "Could not create Android E2E log directory: $logs_dir" >&2
  exit 1
fi

collect_android_logs() {
  adb logcat -d > "$logs_dir/logcat.txt" 2>&1 || true
  adb shell dumpsys activity activities > "$logs_dir/activities.txt" 2>&1 || true
  adb shell dumpsys window windows > "$logs_dir/windows.txt" 2>&1 || true
}

# Retain diagnostics even if the test command cannot be started.
trap collect_android_logs EXIT

# Do not use `set -e` around this pipeline: retain the effective flutter test
# status (or timeout status) rather than allowing tee to obscure it.
set +e
timeout --signal=TERM --kill-after=30s 30m \
  flutter test integration_test/game_flows_test.dart \
    -d emulator-5554 --reporter expanded \
  2>&1 | tee "$logs_dir/flutter-test.txt"
pipeline_status=("${PIPESTATUS[@]}")
set -e

# timeout propagates flutter's exit code and returns 124 on timeout. A failed
# tee is also a CI failure, but it must never mask a failing test.
test_status=${pipeline_status[0]}
tee_status=${pipeline_status[1]}
if [ "$test_status" -eq 0 ] && [ "$tee_status" -ne 0 ]; then
  test_status=$tee_status
fi

# Collect before printing failure diagnostics, and avoid a duplicate trap run.
collect_android_logs
trap - EXIT

if [ "$test_status" -ne 0 ]; then
  echo 'Android integration tests failed. Last 400 logcat lines:' >&2
  tail -n 400 "$logs_dir/logcat.txt" >&2 || true
fi

exit "$test_status"
