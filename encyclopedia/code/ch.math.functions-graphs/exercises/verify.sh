#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
output="$(python3 check.py 2>&1)"
rc=$?
printf '%s\n' "$output"
if [[ $rc -ne 0 ]] && grep -q 'include the upper bound' <<<"$output"; then
  echo "EXPECTED RED: sigma upper bound is omitted" >&2
  exit 1
fi
echo "UNEXPECTED RESULT: intended summation failure was not observed" >&2
exit 2
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.math.functions-graphs oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'EXPECTED RED: sigma upper bound is omitted' <<<"$contract_output" &&
   grep -Fq -- 'EXPECTED RED: sigma upper bound is omitted' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.math.functions-graphs oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.math.functions-graphs expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
