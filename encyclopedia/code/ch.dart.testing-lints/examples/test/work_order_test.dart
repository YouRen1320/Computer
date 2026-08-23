import 'package:dart_testing_lints_example/work_order.dart';
import 'package:test/test.dart';

void main() {
  group('parseWorkOrder', () {
    test('maps a valid urgent order', () {
      final order = parseWorkOrder({'id': 'WO-1', 'priority': 4});
      expect(order.id, equals('WO-1'));
      expect(order.isUrgent, isTrue);
    });

    test('rejects priority outside 1 through 5', () {
      expect(
        () => parseWorkOrder({'id': 'WO-1', 'priority': 9}),
        throwsA(
          isA<InvalidPriority>().having((error) => error.value, 'value', 9),
        ),
      );
    });

    test('rejects an absent id', () {
      expect(
        () => parseWorkOrder({'priority': 3}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('loadWorkOrder exposes asynchronous parse failure', () async {
    await expectLater(
      loadWorkOrder(Future.value({'id': 'WO-2', 'priority': 0})),
      throwsA(isA<InvalidPriority>()),
    );
  });
}
