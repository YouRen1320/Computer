#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

cleanup() { rm -rf .dart_tool; }
trap cleanup EXIT

dart pub get --offline
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
actual="$(dart run bin/main.dart)"
expected='DART_TYPES_EXAMPLE_PASS total=5997 label=unassigned promoted=7'
test "$actual" = "$expected"
printf '%s\n' "$actual"
