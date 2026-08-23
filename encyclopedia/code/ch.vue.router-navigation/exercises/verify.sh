#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
output_file="$(mktemp "${TMPDIR:-/tmp}/factorycare-vue-router-exercise.XXXXXX")"
trap 'rm -f "$output_file"' EXIT
set +e
node scripts/check-route-param.mjs >"$output_file" 2>&1
status=$?
set -e

if [[ $status -eq 0 ]]; then
  cat "$output_file"
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.vue.router-navigation oracle=route-param-contract'
  exit 0
fi
if [[ $status -eq 1 ]] &&
   grep -Fq 'EXPECTED_RED route-param' "$output_file" &&
   grep -Fq 'Watch route.params.workOrderId' "$output_file"; then
  cat "$output_file" >&2
  exit 41
fi

cat "$output_file" >&2
printf '%s\n' "unexpected exercise failure shape: status=$status" >&2
exit 43
