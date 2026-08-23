#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
output="$(uv run --no-project --with pandas --with pytest pytest -q -p no:cacheprovider 2>&1)"
rc=$?
printf '%s\n' "$output"
if [[ $rc -ne 0 ]] && grep -q 'entity leakage' <<<"$output"; then
  echo "EXPECTED RED: an entity crosses train and test" >&2
  exit 1
fi
echo "UNEXPECTED RESULT: intended entity leakage failure was not observed" >&2
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
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.ml.problem-data-split oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'test_manifest.py::test_entities_do_not_cross_splits' <<<"$contract_output" &&
   grep -Fq -- '1 failed' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.ml.problem-data-split oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.ml.problem-data-split expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
