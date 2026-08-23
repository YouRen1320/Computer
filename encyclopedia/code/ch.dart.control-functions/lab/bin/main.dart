import 'package:factorycare_control_lab/dispatch_rules.dart';

void checkEqual(Object? actual, Object? expected) {
  if (actual != expected) {
    throw StateError('expected=$expected actual=$actual');
  }
}

void main() {
  checkEqual(
    dispatchDecision(priority: 1, assigneeAvailable: true),
    'NORMAL_QUEUE',
  );
  checkEqual(
    dispatchDecision(priority: 3, assigneeAvailable: true),
    'EXPEDITED_QUEUE',
  );
  checkEqual(
    dispatchDecision(priority: 5, assigneeAvailable: true),
    'URGENT_DISPATCH',
  );
  checkEqual(
    dispatchDecision(priority: 4, assigneeAvailable: false, retryLimit: 2),
    'QUEUE_RETRY_2',
  );
  checkEqual(boundedAttempts(0), 0);
  checkEqual(boundedAttempts(1), 1);
  checkEqual(boundedAttempts(9), 3);
  print('DART_CONTROL_LAB_GREEN cases=7');
}
