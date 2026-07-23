#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
List<String> preserveTimeline(List<String> events) {
  // TODO: 时间线允许同一种事件重复，Set 破坏了集合合同。
  return events.toSet().toList();
}

void main() {
  final actual = preserveTimeline(<String>['ASSIGNED', 'IN_PROGRESS', 'IN_PROGRESS']);
  print('COLLECTION_CONTRACT_MISMATCH_EXERCISE expected=3 actual=${actual.length}');
  if (actual.length != 3 || actual[2] != 'IN_PROGRESS') {
    throw StateError('timeline must preserve order and duplicates');
  }
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
