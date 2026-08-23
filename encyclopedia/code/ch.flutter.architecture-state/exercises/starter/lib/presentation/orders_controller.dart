import '../data/memory_work_order_reader.dart';
import '../domain/work_order_reader.dart';

sealed class OrdersState {
  const OrdersState();
}

final class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

final class OrdersContent extends OrdersState {
  final List<String> ids;

  OrdersContent(List<String> ids) : ids = List<String>.unmodifiable(ids);
}

final class OrdersController {
  final WorkOrderReader _reader;
  OrdersState state = const OrdersInitial();

  OrdersController(this._reader);

  // TODO：presentation 不应创建 data 实现；由应用组合根负责注入。
  factory OrdersController.withDefaults() =>
      OrdersController(MemoryWorkOrderReader(<String>['WO-DEFAULT']));

  Future<void> load() async {
    state = OrdersContent(await _reader.loadOpenIds());
  }
}
