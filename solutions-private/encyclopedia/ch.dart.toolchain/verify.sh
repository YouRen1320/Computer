#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

cleanup() { rm -rf .dart_tool; }
trap cleanup EXIT

output="$(bash learner_checks.sh 2>&1)"
grep -Fq 'dart_bin=' <<<"$output"
grep -Fq 'DART_TOOLCHAIN_SOLUTION_PASS' <<<"$output"
test -f pubspec.lock
printf '%s\n' 'DART_TOOLCHAIN_SOLUTION_PASS gates=5'
