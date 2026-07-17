#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR" "$ROOT_DIR/node_modules"
}
trap cleanup EXIT

expect_fault() {
  local mode="$1"
  local marker="$2"
  local output
  local status

  set +e
  output="$(node src/lab.mjs "$mode" 2>&1)"
  status=$?
  set -e

  if [[ $status -eq 0 || "$output" != *"$marker"* ]]; then
    echo "expected $marker from mode $mode" >&2
    echo "$output" >&2
    exit 1
  fi
}

cd "$ROOT_DIR"
pnpm install --offline --frozen-lockfile --ignore-scripts >/dev/null
node --check src/lab.mjs
node src/lab.mjs baseline >"$TMP_DIR/baseline.stdout"
[[ "$(cat "$TMP_DIR/baseline.stdout")" == "LAB_BASELINE_PASS layouts=1 listenerDelta=0 timerDelta=0" ]]
expect_fault layout LAYOUT_THRASHING_FAULT
expect_fault listener LISTENER_LEAK_FAULT
expect_fault timer TIMER_RETENTION_FAULT
expect_fault regression PERFORMANCE_REGRESSION_FAULT
echo "BROWSER_PERFORMANCE_LAB_PASS"

