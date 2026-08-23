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
export CI=true
export NO_COLOR=1

cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts >"$TMP_DIR/install.log"
if ! pnpm exec vitest run tests/work-order-summary.test.mjs --reporter=dot >"$TMP_DIR/test.log" 2>&1; then
  cat "$TMP_DIR/test.log" >&2
  exit 1
fi
grep -Eq 'Tests[[:space:]]+5 passed' "$TMP_DIR/test.log"

echo "PASS testing-debugging exercise tests=5"
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.js.testing-debugging oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'UNTRUSTED_ORACLE_EXERCISE' <<<"$contract_output" &&
   grep -Fq -- 'UNTRUSTED_ORACLE_EXERCISE' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.js.testing-debugging oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.js.testing-debugging expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
