#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

cleanup() { rm -rf .dart_tool; }
trap cleanup EXIT

dart pub get --offline
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
test "$(dart run bin/main.dart)" = 'DART_TYPES_SOLUTION_PASS assignee=UNASSIGNED'
printf '%s\n' 'DART_TYPES_SOLUTION_PASS assertions=1'
