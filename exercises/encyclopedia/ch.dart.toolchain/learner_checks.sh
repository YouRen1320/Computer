#!/usr/bin/env bash
set -euo pipefail

# TODO: 记录实际 dart 路径，解析依赖，增加格式和 analyze 门禁。
dart --version
dart run bin/main.dart
