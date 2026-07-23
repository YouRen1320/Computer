import 'dart:async';
import 'dart:isolate';

int countUrgent(List<int> values) => values.where((value) => value >= 4).length;

Future<void> main() async {
  var cleanup = 0;
  late StreamController<int> controller;
  controller = StreamController<int>(onCancel: () => cleanup++);
  final received = <int>[];
  final sub = controller.stream.listen(received.add);
  controller.add(4);
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  await controller.close();
  _check(cleanup == 1 && received.single == 4);
  _check(await Isolate.run(() => countUrgent([5, 2, 4])) == 2);
  print('DART_STREAMS_ISOLATES_SOLUTION_PASS checks=2');
}

void _check(bool condition) {
  if (!condition) throw StateError('solution assertion failed');
}
