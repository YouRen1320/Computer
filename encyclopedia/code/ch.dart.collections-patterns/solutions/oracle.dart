import 'solution.dart';

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
}

void main() {
  final source = <String>['ASSIGNED', 'IN_PROGRESS', 'IN_PROGRESS'];
  final actual = preserveTimeline(source);
  check(actual.join(',') == 'ASSIGNED,IN_PROGRESS,IN_PROGRESS', 'timeline');
  source.add('CLOSED');
  check(actual.length == 3, 'snapshot');
  var blocked = false;
  try {
    actual.add('CLOSED');
  } on UnsupportedError {
    blocked = true;
  }
  check(blocked, 'unmodifiable');
  print('DART_COLLECTIONS_PATTERNS_SOLUTION_PASS checks=3');
}
