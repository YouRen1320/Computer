#!/usr/bin/env bash
set -euo pipefail

export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/fc-flutter-net-exercise.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
Never _fail(String message) => throw StateError(message);

void check(bool condition, String message) {
  if (!condition) _fail(message);
}

final class BrokenReplayClient {
  int _sequence = 0;

  // EXERCISE: generate the key once when accepting the user intent, persist it,
  // and reuse that stored value for every retry and restart.
  String keyForEverySend() => 'new-key-${++_sequence}';
}

final class FakeServer {
  final Set<String> seen = <String>{};
  int businessEffects = 0;

  void submit(String key) {
    if (seen.add(key)) businessEffects++;
  }
}

void main() {
  final client = BrokenReplayClient();
  final server = FakeServer();

  final firstKey = client.keyForEverySend();
  server.submit(firstKey);
  final replayKey = client.keyForEverySend();
  server.submit(replayKey);

  check(
    firstKey == replayKey,
    'IDEMPOTENCY_KEY_CHANGED_ON_REPLAY_EXERCISE first=$firstKey replay=$replayKey',
  );
  check(server.businessEffects == 1, 'duplicate business effect escaped detection');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
