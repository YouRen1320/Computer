#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$ROOT/node_modules"' EXIT

cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts >"$TMP_DIR/install.log"
node --check src/work-order-board.mjs
if ! node src/exercise.mjs >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"; then
  cat "$TMP_DIR/actual.stderr" >&2
  exit 1
fi
cmp expected.stdout "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"

echo "PASS dom-mutation exercise simulator=happy-dom@17.6.3"
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.js.dom-mutation oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'DOM_SELECTION_DRIFT_EXERCISE' <<<"$contract_output" &&
   grep -Fq -- 'DOM_SELECTION_DRIFT_EXERCISE' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.js.dom-mutation oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.js.dom-mutation expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
