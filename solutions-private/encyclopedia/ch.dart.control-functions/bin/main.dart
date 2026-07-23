import 'package:factorycare_control_solution/priority_rule.dart';

void expectEqual(String actual, String expected) {
  if (actual != expected) {
    throw StateError('expected=$expected actual=$actual');
  }
}

void main() {
  expectEqual(priorityBand(0), 'INVALID');
  expectEqual(priorityBand(1), 'NORMAL');
  expectEqual(priorityBand(3), 'NORMAL');
  expectEqual(priorityBand(4), 'URGENT');
  expectEqual(priorityBand(5), 'URGENT');
  expectEqual(priorityBand(6), 'INVALID');
  print('DART_CONTROL_SOLUTION_PASS assertions=6');
}
