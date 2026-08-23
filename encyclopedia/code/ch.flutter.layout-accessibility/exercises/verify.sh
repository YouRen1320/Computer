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
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.flutter.layout-accessibility oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'EXPECTED RED: complete row-overflow.first_evidence, row-overflow.fix, flex-in-unbounded-scroll-axis.first_evidence, flex-in-unbounded-scroll-axis.fix, icon-only-custom-tap-target.first_evidence, icon-only-custom-tap-target.fix, fixed-height-large-text.first_evidence, fixed-height-large-text.fix' <<<"$contract_output" &&
   grep -Fq -- 'EXPECTED RED: complete row-overflow.first_evidence, row-overflow.fix, flex-in-unbounded-scroll-axis.first_evidence, flex-in-unbounded-scroll-axis.fix, icon-only-custom-tap-target.first_evidence, icon-only-custom-tap-target.fix, fixed-height-large-text.first_evidence, fixed-height-large-text.fix' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.flutter.layout-accessibility oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.flutter.layout-accessibility expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
