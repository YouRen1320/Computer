#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

tmp="$(mktemp -d)"
cleanup() { rm -rf .dart_tool "$tmp"; }
trap cleanup EXIT

real_dart="$(command -v dart)"
dart --version
dart pub get --offline
dart format --output=none --set-exit-if-changed bin lib
dart analyze --fatal-infos
test "$(dart run bin/main.dart)" = 'package=factorycare_toolchain_lab gates=pub-get,format,analyze,run'

# 故障 1：PATH 前置伪造工具，必须被路径证据检测出来。
mkdir -p "$tmp/fake-bin"
printf '#!/usr/bin/env bash\nprintf "fake dart\\n"\n' > "$tmp/fake-bin/dart"
chmod +x "$tmp/fake-bin/dart"
resolved_with_fault="$(env PATH="$tmp/fake-bin:$PATH" sh -c 'command -v dart')"
test "$resolved_with_fault" != "$real_dart"

# 故障 2：无效 YAML 必须在 pub get 阶段失败。
mkdir -p "$tmp/bad-pubspec"
cp faults/bad_pubspec.yaml.fixture "$tmp/bad-pubspec/pubspec.yaml"
if (cd "$tmp/bad-pubspec" && dart pub get --offline) >"$tmp/pubspec.log" 2>&1; then
  printf '%s\n' 'expected malformed pubspec to fail' >&2
  exit 1
fi
grep -Eiq 'yaml|line|pubspec|mapping' "$tmp/pubspec.log"

# 故障 3：不存在的 package URI 必须在 analyze 阶段失败。
cp faults/bad_import.dart.fixture "$tmp/bad_import.dart"
if dart analyze "$tmp/bad_import.dart" >"$tmp/import.log" 2>&1; then
  printf '%s\n' 'expected missing package import to fail' >&2
  exit 1
fi
grep -Eiq 'error|does_not_exist|uri' "$tmp/import.log"

# 恢复后重跑原验证，避免“看见红色”却没有证明修复。
test "$(command -v dart)" = "$real_dart"
dart analyze --fatal-infos
test "$(dart run bin/main.dart)" = 'package=factorycare_toolchain_lab gates=pub-get,format,analyze,run'
printf '%s\n' 'DART_TOOLCHAIN_LAB_PASS gates=4 faults=3 rerun=pass'
