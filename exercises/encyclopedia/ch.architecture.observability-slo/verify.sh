#!/usr/bin/env bash
set -u

cd "$(dirname "$0")"
output="$(ruby verify.rb answer.json 2>&1)"
status=$?
if [[ $status -ne 1 ]]; then
  printf '%s\n' "$output"
  printf 'starter verifier must exit 1, got %s\n' "$status" >&2
  exit 2
fi
if ! diff -u expected-red.out <(printf '%s\n' "$output"); then
  printf '%s\n' 'starter red output no longer matches its proof' >&2
  exit 2
fi
printf '%s\n' "$output"
exit 1
