import 'dart:io';

import 'starter/lib/domain/work_order_reader.dart';
import 'starter/lib/presentation/orders_controller.dart';

final class FakeWorkOrderReader implements WorkOrderReader {
  @override
  Future<List<String>> loadOpenIds() async => <String>['WO-FAKE'];
}

Future<void> main() async {
  final problems = <String>[];
  final controller = OrdersController(FakeWorkOrderReader());
  if (controller.state is! OrdersInitial) problems.add('initial-state');
  await controller.load();
  final state = controller.state;
  if (state is! OrdersContent || state.ids.join(',') != 'WO-FAKE') {
    problems.add('fake-substitution-or-content');
  } else {
    var blocked = false;
    try {
      state.ids.add('WO-MUTATION');
    } on UnsupportedError {
      blocked = true;
    }
    if (!blocked) problems.add('content-state-is-mutable');
  }

  if (problems.isNotEmpty) {
    stderr.writeln(
      'UNEXPECTED_FLUTTER_ARCHITECTURE_RUNTIME problems=${problems.join(',')}',
    );
    exitCode = 70;
    return;
  }
  print('FLUTTER_ARCHITECTURE_RUNTIME_PASS checks=3');
}
