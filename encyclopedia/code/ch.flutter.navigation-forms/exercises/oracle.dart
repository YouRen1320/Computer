import 'dart:io';

import 'starter.dart';

void main() {
  final problems = <String>[];

  try {
    final saved = decodeResult(
      resultReturnedByPage(saved: true, orderId: 'WO-9'),
    );
    if (saved is! Saved || saved.orderId != 'WO-9') {
      problems.add('saved-result-contract');
    }
  } on FormatException {
    problems.add('saved-producer-still-untyped');
  }

  try {
    final cancelled = decodeResult(
      resultReturnedByPage(saved: false, orderId: 'WO-9'),
    );
    if (cancelled is! Cancelled) problems.add('cancelled-result-contract');
  } on FormatException {
    problems.add('cancelled-producer-still-untyped');
  }

  var rejectedInvalid = false;
  try {
    decodeResult(true);
  } on FormatException {
    rejectedInvalid = true;
  }
  if (!rejectedInvalid) problems.add('consumer-accepts-contract-drift');

  if (problems.isNotEmpty) {
    stderr.writeln(
      'EXPECTED_FLUTTER_NAVIGATION_FORMS_RED problems=${problems.join(',')}',
    );
    exitCode = 1;
    return;
  }
  print('FLUTTER_NAVIGATION_FORMS_EXERCISE_PASS checks=3');
}
