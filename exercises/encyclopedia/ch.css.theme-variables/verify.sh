#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

output="$(ruby oracle.rb 2>&1)"
rc=$?
if [[ "$rc" -ne 1 ]]; then
  printf 'expected oracle exit 1, got %s\n' "$rc" >&2
  exit 2
fi
printf '%s\n' "$output" | diff -u expected-red.out -
printf '%s\n' "$output"
exit 1
