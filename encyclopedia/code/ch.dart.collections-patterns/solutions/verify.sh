#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
cd "$(dirname "$0")"
dart analyze --fatal-infos solution.dart oracle.dart
dart run oracle.dart
