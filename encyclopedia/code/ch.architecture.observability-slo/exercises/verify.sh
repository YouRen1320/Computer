#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -u

cd "$(dirname "$0")"
output="$(ruby verify.rb answer.json 2>&1)"
status=$?
if [[ $status -ne 1 ]]; then
  printf '%s\n' "$output"
  printf 'starter verifier must exit 1, got %s\n' "$status" >&2
  exit 2
fi
if ! diff -u expected-red.out <(printf '%s\n' "$output"); then
  printf '%s\n' 'starter red output no longer matches its proof' >&2
  exit 2
fi
printf '%s\n' "$output"
exit 1
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.architecture.observability-slo oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'EXERCISE_VERIFIER=RED' <<<"$contract_output" &&
   grep -Fq -- 'EXERCISE_VERIFIER=RED' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.architecture.observability-slo oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.architecture.observability-slo expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
