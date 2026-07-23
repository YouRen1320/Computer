#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
dart analyze --fatal-infos starter.dart oracle.dart
dart run oracle.dart
