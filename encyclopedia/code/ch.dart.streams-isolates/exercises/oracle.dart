import 'dart:io';

import 'starter.dart';

Future<void> main() async {
  final problems = <String>[];
  final broadcast = await observeBroadcastBoundary();
  if (broadcast.received.join(',') != '2' || broadcast.cleanupCount != 1) {
    problems.add('broadcast-no-replay-or-cleanup');
  }

  final worker = await countUrgentInWorker([5, 2, 4]);
  if (worker.urgentCount != 2 || worker.workerName != 'urgent-worker') {
    problems.add('cpu-aggregate-not-in-worker');
  }

  try {
    await preserveWorkerFailure();
    problems.add('worker-error-not-preserved');
  } on StateError catch (error, stack) {
    if (error.message != 'worker-boom' || stack.toString().isEmpty) {
      problems.add('worker-error-shape-lost');
    }
  } catch (_) {
    problems.add('worker-error-type-lost');
  }

  if (await cancelOwnedProducer() != 1) {
    problems.add('cancel-cleanup-not-idempotent');
  }

  if (problems.isNotEmpty) {
    stderr.writeln(
      'EXPECTED_DART_STREAMS_ISOLATES_RED problems=${problems.join(',')}',
    );
    exitCode = 1;
    return;
  }
  print('DART_STREAMS_ISOLATES_EXERCISE_PASS checks=4');
}
