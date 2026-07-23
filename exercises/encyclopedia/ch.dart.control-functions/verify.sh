#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

cleanup() { rm -rf .dart_tool; }
trap cleanup EXIT

dart pub get --offline
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
test "$(dart run bin/main.dart)" = 'DART_CONTROL_EXERCISE_PASS assertions=3'
