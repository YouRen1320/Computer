#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -uo pipefail
cd "$(dirname "$0")"
command -v uv >/dev/null || { echo "UNEXPECTED RED: uv is required" >&2; exit 2; }
export PYTHONDONTWRITEBYTECODE=1
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT
uv run --no-project --with pytest pytest -q -p no:cacheprovider >"$log_file" 2>&1
status=$?
cat "$log_file"
if [[ $status -eq 0 ]]; then
  exit 0
fi
if [[ $status -ne 0 ]] && grep -q 'DID NOT RAISE' "$log_file"; then
  echo "EXPECTED RED: repository failure was swallowed and falsely reported as CLOSED" >&2
  exit 1
fi
echo "UNEXPECTED RESULT: the intended assertion failure was not observed" >&2
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
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.python.testing-logging-debug oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'test_order_service.py::test_repository_failure_is_not_reported_as_business_success' <<<"$contract_output" &&
   grep -Fq -- '1 failed' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.python.testing-logging-debug oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.python.testing-logging-debug expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
