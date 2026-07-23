int countUrgent(List<int> priorities) {
  // TODO：统计大于等于 4 的优先级，随后在 Isolate.run 中调用。
  return -1;
}

final class OwnedSubscription {
  int cleanupCount = 0;

  void cancel() {
    // TODO：取消必须幂等，真实 StreamSubscription.cancel 还要等待 Future。
    cleanupCount++;
  }
}
