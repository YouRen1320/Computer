import 'dart:io';
import 'dart:isolate';

import 'starter.dart';

Future<void> main() async {
  final problems = <String>[];
  final urgent = await Isolate.run(() => countUrgent([5, 2, 4]));
  if (urgent != 2) problems.add('cpu-aggregate');

  final owned = OwnedSubscription();
  owned.cancel();
  owned.cancel();
  if (owned.cleanupCount != 1) problems.add('cancel-cleanup-not-idempotent');

  if (problems.isNotEmpty) {
    stderr.writeln(
      'EXPECTED_DART_STREAMS_ISOLATES_RED problems=${problems.join(',')}',
    );
    exitCode = 1;
    return;
  }
  print('DART_STREAMS_ISOLATES_EXERCISE_PASS checks=2');
}
