#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
final class Resource {
  int closeCount = 0;
  String read() => throw StateError('read failed');
  void close() => closeCount++;
}

String? importBad(Resource resource) {
  try {
    return resource.read();
  } catch (_) {
    // TODO: 宽 catch 静默失败，并且没有 finally 清理资源。
    return null;
  }
}

void main() {
  final resource = Resource();
  var propagated = false;
  try {
    importBad(resource);
  } on StateError {
    propagated = true;
  }
  print('SWALLOWED_EXCEPTION_RESOURCE_LEAK_EXERCISE propagated=$propagated closeCount=${resource.closeCount}');
  if (!propagated || resource.closeCount != 1) {
    throw StateError('unknown failures must propagate and resources must close once');
  }
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
