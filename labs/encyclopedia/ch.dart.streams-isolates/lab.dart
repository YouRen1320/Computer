import 'dart:async';
import 'dart:isolate';

Map<String, int> aggregate(List<String> events) {
  final result = <String, int>{};
  for (final event in events) {
    result[event] = (result[event] ?? 0) + 1;
  }
  return result;
}

Future<void> main() async {
  final trace = <int>[];
  var cleanup = 0;
  late StreamController<int> controller;
  controller = StreamController<int>(onCancel: () => cleanup++);
  final subscription = controller.stream.listen(trace.add);
  controller.add(1);
  await Future<void>.delayed(Duration.zero);
  subscription.pause();
  controller.add(2);
  controller.add(3);
  await Future<void>.delayed(Duration.zero);
  _expect(trace.join(',') == '1', 'paused subscription does not deliver');
  subscription.resume();
  await Future<void>.delayed(Duration.zero);
  _expect(trace.join(',') == '1,2,3', 'buffer drains in order');
  await subscription.cancel();
  await controller.close();
  _expect(cleanup == 1, 'cancel cleanup exactly once');

  final broadcast = StreamController<String>.broadcast();
  final a = <String>[];
  final b = <String>[];
  final aSub = broadcast.stream.listen(a.add);
  broadcast.add('A');
  final bSub = broadcast.stream.listen(b.add);
  broadcast.add('B');
  await Future<void>.delayed(Duration.zero);
  await aSub.cancel();
  await bSub.cancel();
  await broadcast.close();
  _expect(a.join() == 'AB', 'first broadcast listener');
  _expect(b.join() == 'B', 'late broadcast listener misses history');

  final summary = await Isolate.run(
    () => aggregate(['ASSIGNED', 'CLOSED', 'ASSIGNED']),
  );
  _expect(summary['ASSIGNED'] == 2 && summary['CLOSED'] == 1, 'isolate result');
  try {
    await Isolate.run<void>(() => throw FormatException('bad-event'));
    throw StateError('isolate failure was swallowed');
  } on FormatException catch (error) {
    _expect(error.message == 'bad-event', 'isolate error propagated');
  }
  print('DART_STREAMS_ISOLATES_LAB_PASS checks=7 faults=3 cleanup=$cleanup');
}

void _expect(bool condition, String label) {
  if (!condition) throw StateError('CHECK_FAILED:$label');
}
