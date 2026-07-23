#!/usr/bin/env bash
set -euo pipefail

export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/fc-flutter-net-lab.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
import 'dart:async';
import 'dart:convert';

Never _fail(String message) => throw StateError(message);

void check(bool condition, String message) {
  if (!condition) _fail(message);
}

enum CommandState { pending, inFlight, conflict, poisoned, acknowledged }

final class Command {
  final String id;
  final String key;
  final String aggregateId;
  final String kind;
  final int attempt;
  final CommandState state;

  const Command({
    required this.id,
    required this.key,
    required this.aggregateId,
    required this.kind,
    required this.attempt,
    required this.state,
  });

  Command copyWith({int? attempt, CommandState? state}) => Command(
        id: id,
        key: key,
        aggregateId: aggregateId,
        kind: kind,
        attempt: attempt ?? this.attempt,
        state: state ?? this.state,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'key': key,
        'aggregateId': aggregateId,
        'kind': kind,
        'attempt': attempt,
        'state': state.name,
      };

  static Command fromMap(Map<String, Object?> map) => Command(
        id: map['id'] as String,
        key: map['key'] as String,
        aggregateId: map['aggregateId'] as String,
        kind: map['kind'] as String,
        attempt: map['attempt'] as int,
        state: CommandState.values.byName(map['state'] as String),
      );
}

final class MemoryCommandStore {
  final Map<String, Command> commands;

  MemoryCommandStore([Map<String, Command>? initial])
      : commands = initial ?? <String, Command>{};

  String snapshot() => jsonEncode(commands.map(
        (key, value) => MapEntry<String, Object?>(key, value.toMap()),
      ));

  static MemoryCommandStore restartFrom(String snapshot) {
    final raw = jsonDecode(snapshot) as Map<String, Object?>;
    final restored = <String, Command>{};
    for (final entry in raw.entries) {
      final command = Command.fromMap(
        Map<String, Object?>.from(entry.value as Map),
      );
      restored[entry.key] = command.state == CommandState.inFlight
          ? command.copyWith(state: CommandState.pending)
          : command;
    }
    return MemoryCommandStore(restored);
  }
}

enum ServerResult { acknowledged, conflict, poisoned }

final class ResponseLost implements Exception {
  const ResponseLost();
}

final class IdempotentFakeServer {
  final Map<String, ServerResult> _receipts = <String, ServerResult>{};
  final Set<String> loseFirstResponseFor = <String>{};
  final Set<String> _alreadyLost = <String>{};
  int businessEffects = 0;

  ServerResult submit(Command command) {
    final old = _receipts[command.key];
    if (old != null) return old;

    final result = switch (command.kind) {
      'conflict' => ServerResult.conflict,
      'invalid' => ServerResult.poisoned,
      _ => ServerResult.acknowledged,
    };
    _receipts[command.key] = result;
    if (result == ServerResult.acknowledged) businessEffects++;

    if (loseFirstResponseFor.contains(command.key) && _alreadyLost.add(command.key)) {
      throw const ResponseLost();
    }
    return result;
  }
}

final class SyncEngine {
  final MemoryCommandStore store;
  final IdempotentFakeServer server;

  SyncEngine(this.store, this.server);

  void replay(String id) {
    final original = store.commands[id]!;
    final inFlight = original.copyWith(state: CommandState.inFlight);
    store.commands[id] = inFlight;
    try {
      final result = server.submit(inFlight);
      store.commands[id] = switch (result) {
        ServerResult.acknowledged => inFlight.copyWith(state: CommandState.acknowledged),
        ServerResult.conflict => inFlight.copyWith(state: CommandState.conflict),
        ServerResult.poisoned => inFlight.copyWith(state: CommandState.poisoned),
      };
    } on ResponseLost {
      store.commands[id] = inFlight.copyWith(
        attempt: inFlight.attempt + 1,
        state: CommandState.pending,
      );
    }
  }
}

final class Cancelled implements Exception {
  const Cancelled();
}

final class ControlledCall<T> {
  final Completer<T> _completer = Completer<T>();
  bool transportCancelled = false;
  Future<T> get value => _completer.future;

  void cancel() {
    transportCancelled = true;
    if (!_completer.isCompleted) _completer.completeError(const Cancelled());
  }
}

Map<String, Object?> migrateCache(Map<String, Object?> source) {
  final version = source['schemaVersion'];
  if (version == 2) return source;
  if (version == 1) {
    final oldPayload = Map<String, Object?>.from(source['payload'] as Map);
    return <String, Object?>{
      'schemaVersion': 2,
      'payload': <String, Object?>{
        'id': oldPayload['id'],
        'revision': oldPayload['version'] ?? 0,
      },
    };
  }
  throw FormatException('UNSUPPORTED_CACHE_SCHEMA:$version');
}

Future<void> main() async {
  var assertions = 0;

  final controlled = ControlledCall<String>();
  controlled.cancel();
  try {
    await controlled.value;
    _fail('cancel did not end the controlled call');
  } on Cancelled {
    check(controlled.transportCancelled, 'cancel did not reach transport');
    assertions++;
  }

  final cache = migrateCache(<String, Object?>{
    'schemaVersion': 1,
    'payload': <String, Object?>{'id': 'WO-42', 'version': 7},
  });
  check(cache['schemaVersion'] == 2, 'cache schema did not migrate');
  assertions++;
  final payload = Map<String, Object?>.from(cache['payload'] as Map);
  check(payload['revision'] == 7, 'cache migration lost revision');
  assertions++;
  try {
    migrateCache(<String, Object?>{'schemaVersion': 77, 'payload': <String, Object?>{}});
    _fail('future cache schema was guessed');
  } on FormatException catch (error) {
    check('$error'.contains('UNSUPPORTED_CACHE_SCHEMA'), 'wrong cache failure evidence');
    assertions++;
  }

  final initialStore = MemoryCommandStore();
  initialStore.commands['cmd-start'] = const Command(
    id: 'cmd-start',
    key: 'idem-start-42',
    aggregateId: 'WO-42',
    kind: 'start',
    attempt: 0,
    state: CommandState.pending,
  );
  final server = IdempotentFakeServer()..loseFirstResponseFor.add('idem-start-42');
  SyncEngine(initialStore, server).replay('cmd-start');
  check(initialStore.commands['cmd-start']!.state == CommandState.pending,
      'lost response should remain pending');
  assertions++;
  check(server.businessEffects == 1, 'server did not apply first intent');
  assertions++;

  final keyBeforeRestart = initialStore.commands['cmd-start']!.key;
  final restartedStore = MemoryCommandStore.restartFrom(initialStore.snapshot());
  check(restartedStore.commands['cmd-start']!.key == keyBeforeRestart,
      'restart changed idempotency key');
  assertions++;
  SyncEngine(restartedStore, server).replay('cmd-start');
  check(restartedStore.commands['cmd-start']!.state == CommandState.acknowledged,
      'duplicate replay did not recover receipt');
  assertions++;
  check(server.businessEffects == 1, 'duplicate replay repeated business effect');
  assertions++;

  restartedStore.commands['cmd-conflict'] = const Command(
    id: 'cmd-conflict',
    key: 'idem-conflict',
    aggregateId: 'WO-43',
    kind: 'conflict',
    attempt: 0,
    state: CommandState.pending,
  );
  restartedStore.commands['cmd-invalid'] = const Command(
    id: 'cmd-invalid',
    key: 'idem-invalid',
    aggregateId: 'WO-44',
    kind: 'invalid',
    attempt: 0,
    state: CommandState.pending,
  );
  final restartedEngine = SyncEngine(restartedStore, server);
  restartedEngine.replay('cmd-conflict');
  restartedEngine.replay('cmd-invalid');
  check(restartedStore.commands['cmd-conflict']!.state == CommandState.conflict,
      '409-style result was retried instead of isolated');
  assertions++;
  check(restartedStore.commands['cmd-invalid']!.state == CommandState.poisoned,
      'invalid command was not poisoned');
  assertions++;

  print('NETWORK_STORAGE_OFFLINE_LAB_OK assertions=$assertions effects=${server.businessEffects}');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
