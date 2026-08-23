#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
dart analyze --fatal-infos lab.dart
dart run lab.dart
