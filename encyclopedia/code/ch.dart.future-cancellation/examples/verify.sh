#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
dart analyze --fatal-infos example.dart
dart run example.dart
