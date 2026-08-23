final class PersistedCommand {
  final String id;
  final String idempotencyKey;
  final int attempt;

  const PersistedCommand(this.id, this.idempotencyKey, this.attempt);

  PersistedCommand nextAttempt() {
    // TODO：重试属于同一用户意图，不得生成新幂等键。
    return PersistedCommand(
      id,
      '$idempotencyKey-retry-${attempt + 1}',
      attempt + 1,
    );
  }

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
  int businessEffects = 0;

  String submit(PersistedCommand command) =>
      receipts.putIfAbsent(command.idempotencyKey, () {
        businessEffects++;
        return 'receipt-${command.id}';
      });
}
