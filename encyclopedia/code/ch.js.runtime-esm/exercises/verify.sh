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

if ! grep -Fq '"type": "module"' "$ROOT/package.json"; then
  echo "RUNTIME_ESM_EXERCISE_RED: PACKAGE_TYPE_NOT_MODULE" >&2
  exit 1
fi

if ! grep -Fq 'from "./status-label.js"' "$ROOT/src/main.js"; then
  echo "RUNTIME_ESM_EXERCISE_RED: RELATIVE_IMPORT_NEEDS_EXTENSION" >&2
  exit 1
fi

if ! grep -Fq 'import { statusLabel }' "$ROOT/src/main.js"; then
  echo "RUNTIME_ESM_EXERCISE_RED: NAMED_EXPORT_MISMATCH" >&2
  exit 1
fi

node --check "$ROOT/src/status-label.js"
node --check "$ROOT/src/main.js"
node "$ROOT/src/main.js" >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"

echo "PASS runtime-esm exercise exit=0"
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.js.runtime-esm oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'RUNTIME_ESM_EXERCISE_RED:' <<<"$contract_output" &&
   grep -Fq -- 'RUNTIME_ESM_EXERCISE_RED:' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.js.runtime-esm oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.js.runtime-esm expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
