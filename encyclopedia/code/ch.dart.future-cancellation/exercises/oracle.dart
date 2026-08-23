import 'dart:async';
import 'dart:io';

import 'starter.dart';

Future<void> main() async {
  final problems = <String>[];
  final gate = OperationGate();
  final old = gate.begin();
  final current = gate.begin();
  if (gate.mayCommit(old)) problems.add('stale-operation-accepted');
  if (!gate.mayCommit(current)) problems.add('current-operation-rejected');

  final duplicate = CancelToken();
  duplicate.cancel();
  duplicate.cancel();
  if (duplicate.stopCount != 1) problems.add('cancel-not-idempotent');

  final deadline = CancelToken();
  try {
    await withDeadline(
      Completer<String>().future,
      const Duration(milliseconds: 5),
      deadline,
    );
    problems.add('deadline-did-not-fail');
  } on TimeoutException {
    // 预期：deadline 保持超时错误，同时通知底层协作停止。
  }
  if (deadline.stopCount != 1) problems.add('deadline-did-not-cancel');

  if (problems.isNotEmpty) {
    stderr.writeln(
      'EXPECTED_DART_FUTURE_CANCELLATION_RED problems=${problems.join(',')}',
    );
    exitCode = 1;
    return;
  }
  print('DART_FUTURE_CANCELLATION_EXERCISE_PASS checks=4');
}
