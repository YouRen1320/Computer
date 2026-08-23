#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -euo pipefail
cd "$(dirname "$0")"
python3 scripts/check.py
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.python.control-flow oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'AssertionError: EXPECTED RED: expected '"'"'attempt=1\nattempt=2\nattempt=3\n'"'"', got '"'"'attempt=1\nattempt=2\n'"'"'' <<<"$contract_output" &&
   grep -Fq -- 'AssertionError' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.python.control-flow oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.python.control-flow expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
