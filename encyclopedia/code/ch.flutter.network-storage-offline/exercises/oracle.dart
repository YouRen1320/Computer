import 'dart:io';

import 'starter.dart';

void main() {
  final problems = <String>[];
  const accepted = PersistedCommand('cmd-42', 'stable-intent-key-42', 0);
  final server = IdempotentFakeServer();
  final firstReceipt = server.submit(accepted);

  final diskSnapshot = Map<String, Object?>.from(accepted.toMap());
  final replay = PersistedCommand.restore(diskSnapshot).nextAttempt();
  final replayReceipt = server.submit(replay);

  if (replay.id != accepted.id) problems.add('command-id-changed');
  if (replay.idempotencyKey != accepted.idempotencyKey) {
    problems.add('idempotency-key-changed');
  }
  if (replay.attempt != 1) problems.add('attempt-not-incremented');
  if (replayReceipt != firstReceipt) problems.add('receipt-not-reused');
  if (server.businessEffects != 1) problems.add('duplicate-business-effect');

  if (problems.isNotEmpty) {
    stderr.writeln(
      'EXPECTED_FLUTTER_NETWORK_STORAGE_OFFLINE_RED problems=${problems.join(',')}',
    );
    exitCode = 1;
    return;
  }
  print('FLUTTER_NETWORK_STORAGE_OFFLINE_EXERCISE_PASS checks=5');
}
