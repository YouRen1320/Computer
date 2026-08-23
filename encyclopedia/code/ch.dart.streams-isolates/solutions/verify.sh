#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
dart analyze --fatal-infos solution.dart
dart run solution.dart
