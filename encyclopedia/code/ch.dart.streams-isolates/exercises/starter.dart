import 'dart:async';
import 'dart:isolate';

typedef BroadcastObservation = ({List<int> received, int cleanupCount});
typedef WorkerObservation = ({int urgentCount, String? workerName});

int countUrgent(List<int> priorities) {
  return priorities.where((value) => value >= 4).length;
}

Future<BroadcastObservation> observeBroadcastBoundary() async {
  // TODO：用 broadcast controller 证明订阅前事件不回放，并等待 cancel/close。
  return (received: <int>[1, 2], cleanupCount: 0);
}

Future<WorkerObservation> countUrgentInWorker(List<int> priorities) async {
  // TODO：在命名 Isolate.run worker 内同时计算结果和记录 worker identity。
  return (
    urgentCount: countUrgent(priorities),
    workerName: Isolate.current.debugName,
  );
}

Future<void> preserveWorkerFailure() async {
  // TODO：让 Isolate.run 中的 StateError('worker-boom') 原样到达调用者。
}

Future<int> cancelOwnedProducer() async {
  // TODO：创建单订阅 controller，取消同一 subscription 两次并等待清理；返回 onCancel 次数。
  return 2;
}
