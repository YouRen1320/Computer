#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
sealed class EditResult {
  const EditResult();
}

final class Saved extends EditResult {
  final String orderId;
  const Saved(this.orderId);
}

EditResult decodeResult(Object? raw) {
  if (raw is EditResult) return raw;
  throw FormatException('expected EditResult, got ${raw.runtimeType}');
}

void main() {
  const Object resultReturnedByPage = Saved('WO-9');
  final result = decodeResult(resultReturnedByPage);
  if (result is! Saved || result.orderId != 'WO-9') {
    throw StateError('typed result contract');
  }
  print('FLUTTER_NAVIGATION_FORMS_SOLUTION_PASS assertions=2');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
