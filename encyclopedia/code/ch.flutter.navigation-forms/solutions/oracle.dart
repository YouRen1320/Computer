import 'solution.dart';

void main() {
  final saved = decodeResult(
    resultReturnedByPage(saved: true, orderId: 'WO-9'),
  );
  if (saved is! Saved || saved.orderId != 'WO-9') throw StateError('saved');
  final cancelled = decodeResult(
    resultReturnedByPage(saved: false, orderId: 'WO-9'),
  );
  if (cancelled is! Cancelled) throw StateError('cancelled');
  var rejected = false;
  try {
    decodeResult(true);
  } on FormatException {
    rejected = true;
  }
  if (!rejected) throw StateError('fail closed');
  print('FLUTTER_NAVIGATION_FORMS_SOLUTION_PASS checks=3');
}
