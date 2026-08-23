import 'solution.dart';

void main() {
  const accepted = PersistedCommand('cmd-42', 'stable-intent-key-42', 0);
  final server = IdempotentFakeServer();
  final receipt = server.submit(accepted);
  final replay = PersistedCommand.restore(accepted.toMap()).nextAttempt();
  if (replay.id != accepted.id ||
      replay.idempotencyKey != accepted.idempotencyKey ||
      replay.attempt != 1) {
    throw StateError('persisted command identity');
  }
  if (server.submit(replay) != receipt || server.businessEffects != 1) {
    throw StateError('idempotent replay');
  }
  print('FLUTTER_NETWORK_STORAGE_OFFLINE_SOLUTION_PASS checks=5');
}
