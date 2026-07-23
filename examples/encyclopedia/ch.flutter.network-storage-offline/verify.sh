#!/usr/bin/env bash
set -euo pipefail

export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/fc-flutter-net-example.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
import 'dart:async';

Never _fail(String message) => throw StateError(message);

void check(bool condition, String message) {
  if (!condition) _fail(message);
}

final class OperationCancelled implements Exception {
  const OperationCancelled();
}

final class FakeCancelableCall<T> {
  final Completer<T> _completer = Completer<T>();
  bool cancelRequested = false;

  Future<T> get value => _completer.future;

  void complete(T value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  void cancel() {
    cancelRequested = true;
    if (!_completer.isCompleted) {
      _completer.completeError(const OperationCancelled());
    }
  }
}

final class CacheEnvelope {
  static const int currentVersion = 2;
  final int schemaVersion;
  final Map<String, Object?> payload;

  const CacheEnvelope(this.schemaVersion, this.payload);

  static CacheEnvelope decode(Map<String, Object?> source) {
    final version = source['schemaVersion'];
    final payload = source['payload'];
    if (version is! int || payload is! Map) {
      throw const FormatException('CACHE_ENVELOPE_INVALID');
    }
    final typed = Map<String, Object?>.from(payload);
    if (version == 1) {
      return CacheEnvelope(currentVersion, <String, Object?>{
        ...typed,
        'syncState': typed['synced'] == true ? 'synced' : 'local',
      });
    }
    if (version == currentVersion) return CacheEnvelope(version, typed);
    throw FormatException('CACHE_SCHEMA_UNSUPPORTED:$version');
  }
}

final class OfflineCommand {
  final String commandId;
  final String idempotencyKey;
  final int attempt;

  const OfflineCommand(this.commandId, this.idempotencyKey, this.attempt);

  Map<String, Object?> toMap() => <String, Object?>{
        'commandId': commandId,
        'idempotencyKey': idempotencyKey,
        'attempt': attempt,
      };

  static OfflineCommand fromMap(Map<String, Object?> map) => OfflineCommand(
        map['commandId'] as String,
        map['idempotencyKey'] as String,
        map['attempt'] as int,
      );

  OfflineCommand retried() => OfflineCommand(commandId, idempotencyKey, attempt + 1);
}

final class IdempotentServer {
  final Set<String> _receipts = <String>{};
  int businessEffects = 0;

  String submit(OfflineCommand command) {
    if (_receipts.add(command.idempotencyKey)) businessEffects++;
    return 'receipt:${command.idempotencyKey}';
  }
}

Future<void> main() async {
  var assertions = 0;

  final call = FakeCancelableCall<String>();
  call.cancel();
  try {
    await call.value;
    _fail('cancelled call unexpectedly completed');
  } on OperationCancelled {
    check(call.cancelRequested, 'transport did not observe cancellation');
    assertions++;
  }

  final migrated = CacheEnvelope.decode(<String, Object?>{
    'schemaVersion': 1,
    'payload': <String, Object?>{'id': 'WO-42', 'synced': false},
  });
  check(migrated.schemaVersion == 2, 'cache was not migrated');
  assertions++;
  check(migrated.payload['syncState'] == 'local', 'migration changed meaning');
  assertions++;
  try {
    CacheEnvelope.decode(<String, Object?>{
      'schemaVersion': 99,
      'payload': <String, Object?>{},
    });
    _fail('unknown cache schema was accepted');
  } on FormatException catch (error) {
    check('$error'.contains('CACHE_SCHEMA_UNSUPPORTED'), 'wrong schema evidence');
    assertions++;
  }

  const original = OfflineCommand('cmd-42', 'idem-42', 0);
  final restored = OfflineCommand.fromMap(original.toMap()).retried();
  check(restored.idempotencyKey == original.idempotencyKey, 'retry changed idempotency key');
  assertions++;
  check(restored.attempt == 1, 'retry attempt was not recorded');
  assertions++;

  final server = IdempotentServer();
  final first = server.submit(original);
  final duplicate = server.submit(restored);
  check(first == duplicate, 'duplicate did not return original receipt');
  assertions++;
  check(server.businessEffects == 1, 'duplicate caused another business effect');
  assertions++;

  print('NETWORK_STORAGE_OFFLINE_EXAMPLE_OK assertions=$assertions');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
