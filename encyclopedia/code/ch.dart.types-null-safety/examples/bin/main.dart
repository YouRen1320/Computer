void expectEqual(Object? actual, Object? expected, String label) {
  if (actual != expected) {
    throw StateError('$label expected=$expected actual=$actual');
  }
}

String? readAssigneeName() {
  return null;
}

void main() {
  var quantity = 3;
  final unitPriceCents = 1999;
  const taxBasisPoints = 0;
  final total = unitPriceCents * quantity;

  expectEqual(quantity.runtimeType, int, 'inferred int');
  expectEqual(total, 5997, 'integer multiplication');
  expectEqual(taxBasisPoints, 0, 'const value');

  final assigneeName = readAssigneeName();
  final assigneeLabel = assigneeName?.trim().toLowerCase() ?? 'unassigned';
  expectEqual(assigneeLabel, 'unassigned', 'null-aware fallback');

  Object rawPriority = 7;
  var promotedPriority = -1;
  if (rawPriority is int) {
    promotedPriority = rawPriority;
  }
  expectEqual(promotedPriority, 7, 'type promotion');
  expectEqual(rawPriority as int, 7, 'checked cast');
  expectEqual(2 + 3 * 4, 14, 'operator precedence');
  expectEqual((2 + 3) * 4, 20, 'parentheses');

  print(
    'DART_TYPES_EXAMPLE_PASS total=$total '
    'label=$assigneeLabel promoted=$promotedPriority',
  );
}
