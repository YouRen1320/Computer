#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

cleanup() { rm -rf .dart_tool; }
trap cleanup EXIT

DART_BIN="$(command -v dart)"
test -x "$DART_BIN"
printf 'dart_bin=%s\n' "$DART_BIN"
dart --version
dart pub get --offline
test -f .dart_tool/package_config.json
test -f pubspec.lock
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos

actual="$(dart run bin/main.dart)"
expected='DART_TOOLCHAIN_EXAMPLE_PASS label=WO-1001:CREATED'
test "$actual" = "$expected"
printf '%s\n' "$actual"
