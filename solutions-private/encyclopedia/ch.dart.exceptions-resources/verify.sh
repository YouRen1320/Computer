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

String importSafely(Resource resource) {
  try {
    return resource.read();
  } finally {
    resource.close();
  }
}

void main() {
  final resource = Resource();
  Object? caught;
  StackTrace? stack;
  try {
    importSafely(resource);
  } catch (error, caughtStack) {
    caught = error;
    stack = caughtStack;
  }
  if (caught is! StateError) throw StateError('failure type must propagate');
  if (stack == null || !stack.toString().contains('read')) throw StateError('stack must retain origin');
  if (resource.closeCount != 1) throw StateError('resource must close once');
  print('DART_EXCEPTIONS_RESOURCES_SOLUTION_PASS assertions=3');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
