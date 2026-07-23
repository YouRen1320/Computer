#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
List<String> preserveTimeline(List<String> events) =>
    List<String>.unmodifiable(<String>[...events]);

void main() {
  final source = <String>['ASSIGNED', 'IN_PROGRESS', 'IN_PROGRESS'];
  final actual = preserveTimeline(source);
  source.add('CLOSED');
  if (actual.length != 3 || actual[2] != 'IN_PROGRESS') {
    throw StateError('timeline contract failed');
  }
  var blocked = false;
  try {
    actual.add('CLOSED');
  } on UnsupportedError {
    blocked = true;
  }
  if (!blocked) throw StateError('returned timeline must be unmodifiable');
  print('DART_COLLECTIONS_PATTERNS_SOLUTION_PASS assertions=3');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
