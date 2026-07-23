#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

missing=0
for required in 'command -v dart' 'dart pub get --offline' 'dart format --output=none --set-exit-if-changed' 'dart analyze --fatal-infos'; do
  if ! grep -Fq "$required" learner_checks.sh; then
    printf 'TOOLCHAIN_GATE_MISSING: %s\n' "$required" >&2
    missing=$((missing + 1))
  fi
done
test "$missing" -eq 0
