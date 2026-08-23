#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -euo pipefail
cd "$(dirname "$0")"
cleanup() { rm -rf .dart_tool; }
trap cleanup EXIT
dart pub get --offline
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test --reporter expanded
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.dart.testing-lints oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'invalid priority exposes its typed failure' <<<"$contract_output" &&
   grep -Fq -- 'Some tests failed.' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.dart.testing-lints oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.dart.testing-lints expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
