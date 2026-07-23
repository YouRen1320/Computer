import 'package:factorycare_control_exercise/priority_rule.dart';

void expectEqual(String actual, String expected, String label) {
  if (actual != expected) {
    throw StateError('$label expected=$expected actual=$actual');
  }
}

void main() {
  expectEqual(priorityBand(0), 'INVALID', 'lower boundary');
  expectEqual(priorityBand(4), 'URGENT', 'first urgent priority');
  expectEqual(priorityBand(5), 'URGENT', 'highest priority');
  print('DART_CONTROL_EXERCISE_PASS assertions=3');
}
