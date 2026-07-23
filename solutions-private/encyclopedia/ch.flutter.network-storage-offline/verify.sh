#!/usr/bin/env bash
set -euo pipefail

export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/fc-flutter-net-solution.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
Never _fail(String message) => throw StateError(message);

void check(bool condition, String message) {
  if (!condition) _fail(message);
}

final class PersistedCommand {
  final String id;
  final String idempotencyKey;
  final int attempt;

  const PersistedCommand(this.id, this.idempotencyKey, this.attempt);

  PersistedCommand nextAttempt() => PersistedCommand(id, idempotencyKey, attempt + 1);

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'idempotencyKey': idempotencyKey,
        'attempt': attempt,
      };

  static PersistedCommand restore(Map<String, Object?> map) => PersistedCommand(
        map['id'] as String,
        map['idempotencyKey'] as String,
        map['attempt'] as int,
      );
}

final class IdempotentFakeServer {
  final Map<String, String> receipts = <String, String>{};
  int effects = 0;

  String submit(PersistedCommand command) {
    return receipts.putIfAbsent(command.idempotencyKey, () {
      effects++;
      return 'receipt-${command.id}';
    });
  }
}

void main() {
  var assertions = 0;
  const accepted = PersistedCommand('cmd-42', 'stable-intent-key-42', 0);
  final server = IdempotentFakeServer();

  final originalReceipt = server.submit(accepted);
  final afterRestart = PersistedCommand.restore(accepted.toMap()).nextAttempt();
  check(afterRestart.idempotencyKey == accepted.idempotencyKey,
      'solution changed key during restore');
  assertions++;
  final replayReceipt = server.submit(afterRestart);
  check(replayReceipt == originalReceipt, 'solution did not recover original receipt');
  assertions++;
  check(server.effects == 1, 'solution repeated business effect');
  assertions++;

  print('NETWORK_STORAGE_OFFLINE_PRIVATE_OK assertions=$assertions effects=${server.effects}');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
