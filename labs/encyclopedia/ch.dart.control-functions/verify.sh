#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

tmp="$(mktemp -d)"
cleanup() { rm -rf .dart_tool "$tmp"; }
trap cleanup EXIT

dart pub get --offline
dart format --output=none --set-exit-if-changed bin lib
dart analyze --fatal-infos
test "$(dart run bin/main.dart)" = 'DART_CONTROL_LAB_GREEN cases=7'

for fixture in non_exhaustive_switch nullable_condition named_parameter_misuse; do
  cp "faults/$fixture.dart.fixture" "$tmp/$fixture.dart"
  if dart analyze "$tmp/$fixture.dart" >"$tmp/$fixture.log" 2>&1; then
    printf 'expected analyzer failure: %s\n' "$fixture" >&2
    exit 1
  fi
  grep -Eiq 'error|exhaustive|condition|argument|parameter' "$tmp/$fixture.log"
done

dart analyze --fatal-infos
test "$(dart run bin/main.dart)" = 'DART_CONTROL_LAB_GREEN cases=7'
printf '%s\n' 'DART_CONTROL_LAB_PASS cases=7 faults=3 rerun=pass'
