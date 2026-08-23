import 'solution/lib/domain/work_order_reader.dart';
import 'solution/lib/presentation/orders_controller.dart';

final class FakeWorkOrderReader implements WorkOrderReader {
  @override
  Future<List<String>> loadOpenIds() async => <String>['WO-FAKE'];
}

Future<void> main() async {
  final controller = OrdersController(FakeWorkOrderReader());
  if (controller.state is! OrdersInitial) throw StateError('initial');
  await controller.load();
  final state = controller.state as OrdersContent;
  if (state.ids.single != 'WO-FAKE') throw StateError('substitution');
  var blocked = false;
  try {
    state.ids.add('WO-MUTATION');
  } on UnsupportedError {
    blocked = true;
  }
  if (!blocked) throw StateError('immutable state');
  print('FLUTTER_ARCHITECTURE_SOLUTION_PASS checks=3');
}
