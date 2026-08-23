#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
output_file="$(mktemp "${TMPDIR:-/tmp}/factorycare-vue-composable-exercise.XXXXXX")"
trap 'rm -f "$output_file"' EXIT
set +e
node scripts/check-composable-contract.mjs >"$output_file" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  cat "$output_file"
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.vue.composables-di oracle=composable-ownership-contract'
  exit 0
fi
if [[ $status -eq 1 ]] &&
   grep -Fq 'EXPECTED_RED composable-contract' "$output_file" &&
   grep -Fq 'Move mutable refs inside useWorkOrderQuery' "$output_file"; then
  cat "$output_file" >&2
  exit 41
fi

cat "$output_file" >&2
printf '%s\n' "unexpected exercise failure shape: status=$status" >&2
exit 43
