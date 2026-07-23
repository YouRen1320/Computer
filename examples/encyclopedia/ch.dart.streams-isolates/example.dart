import 'dart:async';
import 'dart:isolate';

int countUrgent(List<int> priorities) =>
    priorities.where((priority) => priority >= 4).length;

Future<void> main() async {
  final single = Stream<int>.fromIterable([1, 2, 3]);
  _check(
    await single
        .map((value) => value * 2)
        .toList()
        .then((values) => values.join(',') == '2,4,6'),
  );

  final controller = StreamController<String>.broadcast();
  final first = <String>[];
  final second = <String>[];
  final firstSub = controller.stream.listen(first.add);
  controller.add('assigned');
  final secondSub = controller.stream.listen(second.add);
  controller.add('in-progress');
  await Future<void>.delayed(Duration.zero);
  await firstSub.cancel();
  controller.add('closed');
  await Future<void>.delayed(Duration.zero);
  await secondSub.cancel();
  await controller.close();
  _check(first.join(',') == 'assigned,in-progress');
  _check(second.join(',') == 'in-progress,closed');

  var cleanupCount = 0;
  late StreamController<int> owned;
  owned = StreamController<int>(onCancel: () => cleanupCount++);
  final subscription = owned.stream.listen((_) {});
  await subscription.cancel();
  await owned.close();
  _check(cleanupCount == 1);

  final urgent = await Isolate.run(() => countUrgent([5, 2, 4, 1, 5]));
  _check(urgent == 3);

  try {
    await Isolate.run<int>(() => throw StateError('cpu-fixture'));
    throw StateError('isolate error disappeared');
  } on StateError catch (error) {
    _check(error.message == 'cpu-fixture');
  }

  print('DART_STREAMS_ISOLATES_EXAMPLE_PASS checks=6 native_isolate=true');
}

void _check(bool condition) {
  if (!condition) throw StateError('stream/isolate assertion failed');
}
