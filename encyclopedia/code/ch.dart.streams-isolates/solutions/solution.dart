import 'dart:async';
import 'dart:isolate';

int countUrgent(List<int> values) => values.where((value) => value >= 4).length;

typedef BroadcastObservation = ({List<int> received, int cleanupCount});
typedef WorkerObservation = ({int urgentCount, String? workerName});

Future<BroadcastObservation> observeBroadcastBoundary() async {
  var cleanup = 0;
  final controller = StreamController<int>.broadcast(onCancel: () => cleanup++);
  controller.add(1);
  final received = <int>[];
  final subscription = controller.stream.listen(received.add);
  controller.add(2);
  await Future<void>.delayed(Duration.zero);
  await subscription.cancel();
  await controller.close();
  return (received: received, cleanupCount: cleanup);
}

Future<WorkerObservation> countUrgentInWorker(List<int> values) {
  return Isolate.run(
    () => (
      urgentCount: countUrgent(values),
      workerName: Isolate.current.debugName,
    ),
    debugName: 'urgent-worker',
  );
}

Future<void> preserveWorkerFailure() {
  return Isolate.run<void>(
    () => throw StateError('worker-boom'),
    debugName: 'failing-worker',
  );
}

Future<int> cancelOwnedProducer() async {
  var cleanup = 0;
  final controller = StreamController<int>(onCancel: () => cleanup++);
  final subscription = controller.stream.listen((_) {});
  await subscription.cancel();
  await subscription.cancel();
  await controller.close();
  return cleanup;
}

Future<void> main() async {
  final broadcast = await observeBroadcastBoundary();
  _check(broadcast.received.join(',') == '2' && broadcast.cleanupCount == 1);
  final worker = await countUrgentInWorker([5, 2, 4]);
  _check(worker.urgentCount == 2 && worker.workerName == 'urgent-worker');
  try {
    await preserveWorkerFailure();
    throw StateError('worker error was not preserved');
  } on StateError catch (error, stack) {
    _check(error.message == 'worker-boom' && stack.toString().isNotEmpty);
  }
  _check(await cancelOwnedProducer() == 1);
  print('DART_STREAMS_ISOLATES_SOLUTION_PASS checks=4');
}

void _check(bool condition) {
  if (!condition) throw StateError('solution assertion failed');
}
