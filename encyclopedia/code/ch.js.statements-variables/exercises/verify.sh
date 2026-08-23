#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
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
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.js.statements-variables oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'STATEMENTS_VARIABLES_EXERCISE_RED:' <<<"$contract_output" &&
   grep -Fq -- 'STATEMENTS_VARIABLES_EXERCISE_RED:' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.js.statements-variables oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.js.statements-variables expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
