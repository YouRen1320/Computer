#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

tmp="$(mktemp -d)"
cleanup() { rm -rf .dart_tool "$tmp"; }
trap cleanup EXIT

dart pub get --offline
dart format --output=none --set-exit-if-changed bin
dart analyze --fatal-infos
test "$(dart run bin/main.dart)" = 'DART_TYPES_LAB_GREEN rows=6'

cp faults/null_assignment.dart.fixture "$tmp/null_assignment.dart"
if dart analyze "$tmp/null_assignment.dart" >"$tmp/null.log" 2>&1; then
  printf '%s\n' 'expected nullable assignment analysis failure' >&2
  exit 1
fi
grep -Eiq 'error|null|assign' "$tmp/null.log"

cp faults/late_read.dart.fixture "$tmp/late_read.dart"
dart analyze "$tmp/late_read.dart" >"$tmp/late-analyze.log" 2>&1
if dart run "$tmp/late_read.dart" >"$tmp/late-run.log" 2>&1; then
  printf '%s\n' 'expected late read runtime failure' >&2
  exit 1
fi
grep -Eiq 'LateInitializationError|not been initialized' "$tmp/late-run.log"

cp faults/bad_cast.dart.fixture "$tmp/bad_cast.dart"
dart analyze "$tmp/bad_cast.dart" >"$tmp/cast-analyze.log" 2>&1
if dart run "$tmp/bad_cast.dart" >"$tmp/cast-run.log" 2>&1; then
  printf '%s\n' 'expected checked cast runtime failure' >&2
  exit 1
fi
grep -Eiq 'type.*String.*int|type cast' "$tmp/cast-run.log"

dart analyze --fatal-infos
test "$(dart run bin/main.dart)" = 'DART_TYPES_LAB_GREEN rows=6'
printf '%s\n' 'DART_TYPES_LAB_PASS rows=6 faults=3 rerun=pass'
