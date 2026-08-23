void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

late final String startupToken;

String? readAssigneeName() {
  return null;
}

void main() {
  final String status = 'IN_PROGRESS';
  final assignee = readAssigneeName();
  final normalizedAssignee = assignee?.trim().toUpperCase() ?? 'UNASSIGNED';
  startupToken = 'factorycare-ready';

  Object priority = 4;
  check(priority is int, 'priority should promote to int');
  if (priority is int) {
    check(priority >= 4, 'promoted comparison should work');
  }
  check(status.length == 11, 'status length');
  check(normalizedAssignee == 'UNASSIGNED', 'nullable fallback');
  check(startupToken == 'factorycare-ready', 'late assignment before read');
  check(10 ~/ 3 == 3, 'integer division');

  print('DART_TYPES_LAB_GREEN rows=6');
}
