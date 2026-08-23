#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -euo pipefail
cd "$(dirname "$0")"
ruby scripts/check_answers.rb
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.flutter.state-lifecycle oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'EXPECTED RED: complete mounted_is_boolean, mounted_means_route_is_visible, mounted_cancels_http, mounted_prevents_duplicate_calls, mounted_can_guard_post_dispose_set_state, finally_needs_operation_identity_check, dispose_should_release_owned_resources, stable_key_keeps_state_with_business_item, did_change_dependencies_may_run_more_than_once' <<<"$contract_output" &&
   grep -Fq -- 'EXPECTED RED: complete mounted_is_boolean, mounted_means_route_is_visible, mounted_cancels_http, mounted_prevents_duplicate_calls, mounted_can_guard_post_dispose_set_state, finally_needs_operation_identity_check, dispose_should_release_owned_resources, stable_key_keeps_state_with_business_item, did_change_dependencies_may_run_more_than_once' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.flutter.state-lifecycle oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.flutter.state-lifecycle expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
