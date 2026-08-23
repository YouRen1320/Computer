import 'dart:async';

final class CancelledOperation implements Exception {
  const CancelledOperation(this.reason);
  final String reason;
}

final class CancellationToken {
  bool _cancelled = false;
  String? _reason;
  final List<void Function(String)> _listeners = [];

  bool get isCancelled => _cancelled;

  void onCancel(void Function(String) listener) {
    if (_cancelled) {
      listener(_reason!);
    } else {
      _listeners.add(listener);
    }
  }

  void cancel(String reason) {
    if (_cancelled) return;
    _cancelled = true;
    _reason = reason;
    for (final listener in List.of(_listeners)) {
      listener(reason);
    }
    _listeners.clear();
  }
}

final class ControlledRequest<T> {
  ControlledRequest(CancellationToken token) {
    token.onCancel((reason) {
      cancellations++;
      if (!completer.isCompleted) {
        completer.completeError(CancelledOperation(reason));
      }
    });
  }

  final Completer<T> completer = Completer<T>();
  int cancellations = 0;
  Future<T> get future => completer.future;
}

final class LatestCommitter<T> {
  int _generation = 0;
  T? value;

  int begin() => ++_generation;

  bool commit(int generation, T next) {
    if (generation != _generation) return false;
    value = next;
    return true;
  }
}

Future<void> main() async {
  final successToken = CancellationToken();
  final success = ControlledRequest<String>(successToken);
  scheduleMicrotask(() => success.completer.complete('WO-100'));
  _check(await success.future == 'WO-100', 'future value completion');

  final failed = Completer<String>();
  scheduleMicrotask(() => failed.completeError(StateError('transport')));
  try {
    await failed.future;
    throw StateError('future error was swallowed');
  } on StateError catch (error) {
    _check(error.message == 'transport', 'future error propagation');
  }

  final cancelToken = CancellationToken();
  final cancelled = ControlledRequest<String>(cancelToken);
  cancelToken.cancel('page-disposed');
  try {
    await cancelled.future;
    throw StateError('cancellation was ignored');
  } on CancelledOperation catch (error) {
    _check(error.reason == 'page-disposed', 'cancellation reason');
  }
  _check(cancelled.cancellations == 1, 'cancel exactly once');
  cancelToken.cancel('duplicate');
  _check(cancelled.cancellations == 1, 'duplicate cancel is idempotent');

  final commits = LatestCommitter<String>();
  final oldGeneration = commits.begin();
  final newGeneration = commits.begin();
  _check(commits.commit(newGeneration, 'new'), 'latest result commits');
  _check(!commits.commit(oldGeneration, 'old'), 'stale result is rejected');
  _check(commits.value == 'new', 'stale result cannot overwrite state');

  final source = Completer<String>();
  var sourceStillRan = false;
  source.future.then((_) => sourceStillRan = true);
  final timed = source.future.timeout(
    const Duration(milliseconds: 5),
    onTimeout: () => 'timeout-view',
  );
  _check(await timed == 'timeout-view', 'timeout alternative result');
  source.complete('late-source-value');
  await Future<void>.delayed(Duration.zero);
  _check(sourceStillRan, 'timeout did not cancel source future');

  print(
    'DART_FUTURE_CANCELLATION_EXAMPLE_PASS checks=10 runtime=${PlatformVersion.label}',
  );
}

void _check(bool condition, String label) {
  if (!condition) throw StateError('CHECK_FAILED:$label');
}

abstract final class PlatformVersion {
  static const label = 'dart-core-compatible';
}
