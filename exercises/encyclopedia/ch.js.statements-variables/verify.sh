#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! grep -Fq 'const workOrderId = "WO-1001";' "$ROOT/src/state-trace.mjs"; then
  echo "STATEMENTS_VARIABLES_EXERCISE_RED: WORK_ORDER_ID_MUST_BE_CONST" >&2
  exit 1
fi

if ! grep -Fq 'let currentStatus = "CREATED";' "$ROOT/src/state-trace.mjs"; then
  echo "STATEMENTS_VARIABLES_EXERCISE_RED: CURRENT_STATUS_MUST_BE_LET" >&2
  exit 1
fi

node --check "$ROOT/src/state-trace.mjs"
node "$ROOT/src/state-trace.mjs" >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"
test ! -s "$TMP_DIR/actual.stderr"
if ! cmp -s "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout"; then
  echo "STATEMENTS_VARIABLES_EXERCISE_RED: STATE_PREDICTION_MISMATCH" >&2
  diff -u "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout" >&2 || true
  exit 1
fi

echo "PASS statements-variables exercise exit=0"
