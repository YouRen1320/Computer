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

node --check "$ROOT/src/value-contract.mjs"
if ! node "$ROOT/src/value-contract.mjs" >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"; then
  cat "$TMP_DIR/actual.stderr" >&2
  exit 1
fi

if ! grep -Fq 'retryCount === 0' "$ROOT/src/value-contract.mjs"; then
  echo "VALUES_OPERATORS_EXERCISE_RED: STRICT_EQUALITY_REQUIRED" >&2
  exit 1
fi
if ! grep -Fq 'retryCount ?? 3' "$ROOT/src/value-contract.mjs"; then
  echo "VALUES_OPERATORS_EXERCISE_RED: NULLISH_COALESCING_REQUIRED" >&2
  exit 1
fi

cmp "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"
echo "PASS values-operators exercise exit=0"
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.js.values-operators oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'TYPEOF_NULL_ORACLE' <<<"$contract_output" &&
   grep -Fq -- 'AssertionError [ERR_ASSERTION]' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.js.values-operators oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.js.values-operators expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
