final class InvalidPriority implements Exception {
  const InvalidPriority(this.value);
  final int value;
}

Future<int> normalizePriority(int value) async {
  // TODO：非法优先级必须异步抛出 InvalidPriority，不能用 1 掩盖错误。
  if (value < 1 || value > 5) return 1;
  return value;
}
