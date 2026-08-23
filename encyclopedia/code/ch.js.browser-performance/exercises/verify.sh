#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

cleanup() {
  rm -rf "$ROOT_DIR/node_modules"
}
trap cleanup EXIT

cd "$ROOT_DIR"
pnpm install --offline --frozen-lockfile --ignore-scripts >/dev/null
node --check src/exercise.mjs
node src/exercise.mjs

) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.js.browser-performance oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'PERFORMANCE_BUDGET_EXERCISE' <<<"$contract_output" &&
   grep -Fq -- 'PERFORMANCE_BUDGET_EXERCISE' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.js.browser-performance oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.js.browser-performance expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
