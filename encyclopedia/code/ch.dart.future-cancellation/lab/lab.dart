import 'dart:async';

final class CancellationSignal {
  bool cancelled = false;
  int stopCount = 0;
  final Completer<void> _stopped = Completer<void>();

  Future<void> get stopped => _stopped.future;

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    stopCount++;
    _stopped.complete();
  }
}

final class WorkOrderLoader {
  int _operation = 0;
  String? visibleId;

  int begin() => ++_operation;

  Future<bool> accept(int operation, Future<String> source) async {
    final value = await source;
    if (operation != _operation) return false;
    visibleId = value;
    return true;
  }
}

Future<String> cooperativeLoad(
  Completer<String> network,
  CancellationSignal signal,
) async {
  final outcome = await Future.any<Object?>([
    network.future.then<Object?>((value) => value),
    signal.stopped.then<Object?>((_) => null),
  ]);
  if (signal.cancelled) throw StateError('cancelled');
  return outcome as String;
}

Future<void> main() async {
  final loader = WorkOrderLoader();
  final old = Completer<String>();
  final current = Completer<String>();
  final oldId = loader.begin();
  final oldCommit = loader.accept(oldId, old.future);
  final currentId = loader.begin();
  final currentCommit = loader.accept(currentId, current.future);
  current.complete('WO-NEW');
  old.complete('WO-OLD');
  _expect(await currentCommit, 'current result accepted');
  _expect(!await oldCommit, 'late old result rejected');
  _expect(loader.visibleId == 'WO-NEW', 'visible state remains newest');

  final signal = CancellationSignal();
  final never = Completer<String>();
  final cancelled = cooperativeLoad(never, signal);
  signal.cancel();
  signal.cancel();
  await _expectThrows(cancelled, 'cooperative cancellation');
  _expect(signal.stopCount == 1, 'source stop invoked exactly once');

  final slow = Completer<String>();
  var underlyingCompleted = false;
  slow.future.then((_) => underlyingCompleted = true);
  final timeoutView = await slow.future.timeout(
    const Duration(milliseconds: 5),
    onTimeout: () => 'deadline',
  );
  _expect(timeoutView == 'deadline', 'deadline result');
  slow.complete('late');
  await Future<void>.delayed(Duration.zero);
  _expect(underlyingCompleted, 'source continues after timeout');

  final failure = Completer<String>();
  scheduleMicrotask(() => failure.completeError(FormatException('bad-json')));
  try {
    await failure.future;
    throw StateError('failure lost');
  } on FormatException catch (error) {
    _expect(error.message == 'bad-json', 'typed failure preserved');
  }
  print('DART_FUTURE_CANCELLATION_LAB_PASS checks=8 faults=3');
}

Future<void> _expectThrows(Future<Object?> future, String label) async {
  try {
    await future;
  } on StateError catch (error) {
    if (error.message == 'cancelled') return;
  }
  throw StateError('CHECK_FAILED:$label');
}

void _expect(bool condition, String label) {
  if (!condition) throw StateError('CHECK_FAILED:$label');
}
