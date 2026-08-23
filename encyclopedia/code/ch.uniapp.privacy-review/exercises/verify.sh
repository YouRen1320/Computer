#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -euo pipefail
cd "$(dirname "$0")"
node oracle.mjs
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.uniapp.privacy-review oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'EXPECTED_UNIAPP_PRIVACY_REVIEW_RED' <<<"$contract_output" &&
   grep -Fq -- 'EXPECTED_UNIAPP_PRIVACY_REVIEW_RED' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.uniapp.privacy-review oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.uniapp.privacy-review expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
