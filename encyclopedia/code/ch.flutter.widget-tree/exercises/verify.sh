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
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.flutter.widget-tree oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'EXPECTED RED: complete widget_is_mutable_screen_object, context_can_find_descendant, stateless_widget_can_rebuild, build_may_run_many_times, stable_value_key_can_follow_order_id, hot_reload_always_recreates_state' <<<"$contract_output" &&
   grep -Fq -- 'EXPECTED RED: complete widget_is_mutable_screen_object, context_can_find_descendant, stateless_widget_can_rebuild, build_may_run_many_times, stable_value_key_can_follow_order_id, hot_reload_always_recreates_state' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.flutter.widget-tree oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.flutter.widget-tree expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
