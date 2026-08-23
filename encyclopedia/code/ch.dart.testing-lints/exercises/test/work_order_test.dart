import 'package:dart_testing_lints_exercise/work_order.dart';
import 'package:test/test.dart';

void main() {
  test('valid priority is retained', () async {
    expect(await normalizePriority(4), equals(4));
  });

  test('invalid priority exposes its typed failure', () async {
    await expectLater(normalizePriority(9), throwsA(isA<InvalidPriority>()));
  });
}
