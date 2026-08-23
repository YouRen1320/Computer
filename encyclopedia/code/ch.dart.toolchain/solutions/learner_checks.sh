#!/usr/bin/env bash
set -euo pipefail

DART_BIN="$(command -v dart)"
printf 'dart_bin=%s\n' "$DART_BIN"
dart --version
dart pub get --offline
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart run bin/main.dart
