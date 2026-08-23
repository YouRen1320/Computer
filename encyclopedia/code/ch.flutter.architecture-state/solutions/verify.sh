#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
cd "$(dirname "$0")"
if grep -REq '^import .*data/' solution/lib/presentation; then
  echo 'architecture rule failed: presentation imports data' >&2
  exit 51
fi
if grep -REq '^import .*(presentation|data)/|^import .*package:flutter' solution/lib/domain; then
  echo 'architecture rule failed: domain imports outer layer' >&2
  exit 52
fi
dart analyze --fatal-infos solution oracle.dart
dart run oracle.dart
