import 'dart:async';

final class OperationGate {
  int _current = 0;

  int begin() => ++_current;

  bool mayCommit(int operationId) {
    // TODO：只有当前 operationId 才能提交。
    return false;
  }
}

final class CancelToken {
  int stopCount = 0;

  void cancel() {
    // TODO：重复取消必须幂等。
    stopCount++;
  }
}

Future<T> withDeadline<T>(Future<T> source, Duration limit, CancelToken token) {
  // TODO：超时时通知 token；注意 timeout 不会自动停止 source。
  return source.timeout(limit);
}
