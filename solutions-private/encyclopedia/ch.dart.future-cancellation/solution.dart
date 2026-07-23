import 'dart:async';

final class CancelToken {
  bool _cancelled = false;
  int stopCount = 0;
  final Completer<void> _stop = Completer<void>();

  Future<void> get stopped => _stop.future;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    stopCount++;
    _stop.complete();
  }
}

final class OperationGate {
  int _current = 0;
  int begin() => ++_current;
  bool mayCommit(int id) => id == _current;
}

Future<T> withDeadline<T>(
  Future<T> source,
  Duration limit,
  CancelToken token,
) => source.timeout(
  limit,
  onTimeout: () {
    token.cancel();
    throw TimeoutException('operation deadline exceeded', limit);
  },
);

Future<void> main() async {
  final gate = OperationGate();
  final old = gate.begin();
  final current = gate.begin();
  _check(!gate.mayCommit(old));
  _check(gate.mayCommit(current));

  final token = CancelToken();
  final timeout = Completer<void>();
  final outcome = Future.any<String>([
    token.stopped.then((_) => 'cancelled'),
    timeout.future.then((_) => 'done'),
  ]);
  token.cancel();
  token.cancel();
  _check(await outcome == 'cancelled');
  _check(token.stopCount == 1);

  final deadline = CancelToken();
  try {
    await withDeadline(
      Completer<String>().future,
      const Duration(milliseconds: 5),
      deadline,
    );
    throw StateError('deadline did not fail');
  } on TimeoutException {
    _check(deadline.stopCount == 1);
  }
  print('DART_FUTURE_CANCELLATION_SOLUTION_PASS checks=5');
}

void _check(bool condition) {
  if (!condition) throw StateError('solution assertion failed');
}
