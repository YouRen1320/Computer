#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
abstract interface class SyncResource {
  String read();
  void close();
}

final class RecordingResource implements SyncResource {
  final String value;
  final bool failRead;
  int closeCount = 0;
  RecordingResource(this.value, {this.failRead = false});
  @override
  String read() {
    if (failRead) throw StateError('read failed');
    return value;
  }
  @override
  void close() => closeCount++;
}

T usingResource<T>(SyncResource resource, T Function(SyncResource) body) {
  try {
    return body(resource);
  } finally {
    resource.close();
  }
}

int parsePriority(String raw) {
  final value = int.tryParse(raw);
  if (value == null) throw FormatException('not an integer');
  if (value < 1 || value > 5) throw RangeError.range(value, 1, 5, 'priority');
  return value;
}

int parseWithAudit(String raw) {
  try {
    return parsePriority(raw);
  } catch (_) {
    rethrow;
  }
}

void expect(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  var assertions = 0;
  void check(bool value, String label) {
    assertions++;
    expect(value, label);
  }

  final success = RecordingResource('5');
  final parsed = usingResource(success, (resource) => parsePriority(resource.read()));
  check(parsed == 5, 'success value');
  check(success.closeCount == 1, 'success cleanup once');

  final failedRead = RecordingResource('unused', failRead: true);
  Object? readError;
  try {
    usingResource(failedRead, (resource) => resource.read());
  } catch (error) {
    readError = error;
  }
  check(readError is StateError, 'read error propagates');
  check(failedRead.closeCount == 1, 'failure cleanup once');

  Object? parseError;
  StackTrace? parseStack;
  try {
    parseWithAudit('bad');
  } catch (error, stackTrace) {
    parseError = error;
    parseStack = stackTrace;
  }
  check(parseError is FormatException, 'typed parse failure');
  check(parseStack != null && parseStack.toString().contains('parsePriority'), 'original stack retained');

  var rangeCaught = false;
  try {
    parsePriority('6');
  } on RangeError {
    rangeCaught = true;
  }
  check(rangeCaught, 'range failure is distinct');
  print('DART_EXCEPTIONS_RESOURCES_EXAMPLE_PASS assertions=$assertions');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
