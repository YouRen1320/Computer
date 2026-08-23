#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
cd "$(dirname "$0")"
dart analyze --fatal-infos starter oracle.dart
dart run oracle.dart

if grep -REq '^import .*data/' starter/lib/presentation; then
  printf '%s\n' 'EXPECTED_FLUTTER_ARCHITECTURE_RED forbidden=presentation-to-data' >&2
  exit 1
fi
if grep -REq '^import .*(presentation|data)/|^import .*package:flutter' starter/lib/domain; then
  printf '%s\n' 'EXPECTED_FLUTTER_ARCHITECTURE_RED forbidden=domain-to-outer-layer' >&2
  exit 1
fi
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then printf '%s\n' "$contract_output"; fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.flutter.architecture-state oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'EXPECTED_FLUTTER_ARCHITECTURE_RED' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.flutter.architecture-state oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.flutter.architecture-state expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
