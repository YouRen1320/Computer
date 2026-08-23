import 'dart:io';

import 'starter.dart';

void main() {
  final problems = <String>[];

  final success = Resource.success('WO-7');
  try {
    if (importSafely(success) != 'WO-7') problems.add('success-value-lost');
  } catch (_) {
    problems.add('success-threw');
  }
  if (success.closeCount != 1) problems.add('success-close-count');

  final failure = Resource.failure(StateError('read-origin'));
  Object? caught;
  StackTrace? caughtStack;
  try {
    importSafely(failure);
  } catch (error, stack) {
    caught = error;
    caughtStack = stack;
  }
  if (caught is! StateError || caught.message != 'read-origin') {
    problems.add('failure-type-or-message-lost');
  }
  if (caughtStack == null ||
      !caughtStack.toString().contains('Resource.read')) {
    problems.add('failure-stack-origin-lost');
  }
  if (failure.closeCount != 1) problems.add('failure-close-count');

  if (problems.isNotEmpty) {
    stderr.writeln(
      'EXPECTED_DART_EXCEPTIONS_RESOURCES_RED problems=${problems.join(',')}',
    );
    exitCode = 1;
    return;
  }
  print('DART_EXCEPTIONS_RESOURCES_EXERCISE_PASS checks=5');
}
