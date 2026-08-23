import 'package:factorycare_control_example/repair_rules.dart';

void expectEqual(Object? actual, Object? expected, String label) {
  if (actual != expected) {
    throw StateError('$label expected=$expected actual=$actual');
  }
}

void main() {
  expectEqual(priorityBand(1), 'LOW', 'low branch');
  expectEqual(priorityBand(3), 'MEDIUM', 'medium branch');
  expectEqual(priorityBand(4), 'URGENT', 'urgent branch');
  expectEqual(priorityBand(0), 'INVALID', 'boundary branch');
  expectEqual(countUrgentWindows(5, firstUrgentAt: 3), 2, 'for and continue');
  expectEqual(consumeRetryBudget(9), 3, 'while and break');
  expectEqual(runAtLeastOnce(0), 1, 'do-while');
  expectEqual(isDispatchable(5), true, 'arrow function');

  print('DART_CONTROL_EXAMPLE_PASS assertions=8');
}
