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
  // TODO: 页面目前返回 bool；请把生产者和消费者统一为类型化结果合同。
  if (raw is EditResult) return raw;
  throw FormatException('expected EditResult, got ${raw.runtimeType}');
}

void main() {
  final Object? resultReturnedByPage = true;
  print('ROUTE_RESULT_CONTRACT_DRIFT_EXERCISE raw=$resultReturnedByPage');
  final result = decodeResult(resultReturnedByPage);
  if (result is! Saved || result.orderId != 'WO-9') {
    throw StateError('saved result missing');
  }
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
