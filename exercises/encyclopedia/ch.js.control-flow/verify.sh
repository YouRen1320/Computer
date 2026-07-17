#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! grep -Fq 'const retryIsValid = rawRetryCount.trim() !== "" && Number.isInteger(retryCount) && retryCount >= 0 && retryCount <= 3;' "$ROOT/src/priority.mjs"; then
  echo "CONTROL_FLOW_EXERCISE_RED: TRUTHINESS_REJECTS_ZERO" >&2
  exit 1
fi
if ! grep -Fq 'case "P2":' "$ROOT/src/priority.mjs"; then
  echo "CONTROL_FLOW_EXERCISE_RED: MISSING_P2_SWITCH_BRANCH" >&2
  exit 1
fi
if ! grep -Fq 'retryIndex < retryCount' "$ROOT/src/priority.mjs"; then
  echo "CONTROL_FLOW_EXERCISE_RED: LOOP_UPPER_BOUND_OFF_BY_ONE" >&2
  exit 1
fi

run_case() {
  local name="$1"
  local score="$2"
  local retry_count="$3"
  local expected_file="$4"
  local expected_exit="$5"
  local actual_exit=0
  node "$ROOT/src/priority.mjs" "$score" "$retry_count" >"$TMP_DIR/$name.stdout" 2>"$TMP_DIR/$name.stderr" || actual_exit=$?
  if (( actual_exit != expected_exit )); then
    echo "CONTROL_FLOW_EXERCISE_RED: case=$name expected_exit=$expected_exit actual_exit=$actual_exit" >&2
    exit 1
  fi
  cmp "$ROOT/$expected_file" "$TMP_DIR/$name.stdout"
  test ! -s "$TMP_DIR/$name.stderr"
}

run_case zero 80 0 expected-zero.stdout 0
run_case one 50 1 expected-one.stdout 0
run_case many 49 3 expected-many.stdout 0
run_case invalid bad 1 expected-invalid.stdout 2

echo "PASS control-flow exercise cases=4"
