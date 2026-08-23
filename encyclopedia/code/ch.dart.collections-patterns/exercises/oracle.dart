import 'dart:io';

import 'starter.dart';

void main() {
  final problems = <String>[];
  final source = <String>['ASSIGNED', 'IN_PROGRESS', 'IN_PROGRESS'];
  final actual = preserveTimeline(source);

  if (actual.join(',') != 'ASSIGNED,IN_PROGRESS,IN_PROGRESS') {
    problems.add('order-or-duplicates-lost');
  }
  source.add('CLOSED');
  if (actual.length != 3) problems.add('result-aliases-source');

  var mutationBlocked = false;
  try {
    actual.add('CLOSED');
  } on UnsupportedError {
    mutationBlocked = true;
  }
  if (!mutationBlocked) problems.add('result-is-mutable');

  if (problems.isNotEmpty) {
    stderr.writeln(
      'EXPECTED_DART_COLLECTIONS_PATTERNS_RED problems=${problems.join(',')}',
    );
    exitCode = 1;
    return;
  }
  print('DART_COLLECTIONS_PATTERNS_EXERCISE_PASS checks=3');
}
