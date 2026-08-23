import 'solution.dart';

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
}

void main() {
  final success = Resource.success('WO-7');
  check(importSafely(success) == 'WO-7', 'success value');
  check(success.closeCount == 1, 'success close');

  final failure = Resource.failure(StateError('read-origin'));
  Object? caught;
  StackTrace? stack;
  try {
    importSafely(failure);
  } catch (error, trace) {
    caught = error;
    stack = trace;
  }
  check(caught is StateError && caught.message == 'read-origin', 'error shape');
  check(stack != null && stack.toString().contains('Resource.read'), 'stack');
  check(failure.closeCount == 1, 'failure close');
  print('DART_EXCEPTIONS_RESOURCES_SOLUTION_PASS checks=5');
}
