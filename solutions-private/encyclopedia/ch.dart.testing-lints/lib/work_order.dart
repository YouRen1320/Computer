final class InvalidPriority implements Exception {
  const InvalidPriority(this.value);
  final int value;
}

Future<int> normalizePriority(int value) async {
  if (value < 1 || value > 5) throw InvalidPriority(value);
  return value;
}
