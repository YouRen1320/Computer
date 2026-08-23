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
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.flutter.toolchain-project oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'EXPECTED RED: complete wrong-sdk.first_stage, wrong-sdk.first_evidence, wrong-sdk.recovery, missing-device.first_stage, missing-device.first_evidence, missing-device.recovery, changed-native-permission-after-reload.first_stage, changed-native-permission-after-reload.first_evidence, changed-native-permission-after-reload.recovery' <<<"$contract_output" &&
   grep -Fq -- 'EXPECTED RED: complete wrong-sdk.first_stage, wrong-sdk.first_evidence, wrong-sdk.recovery, missing-device.first_stage, missing-device.first_evidence, missing-device.recovery, changed-native-permission-after-reload.first_stage, changed-native-permission-after-reload.first_evidence, changed-native-permission-after-reload.recovery' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.flutter.toolchain-project oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.flutter.toolchain-project expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
