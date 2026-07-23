#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
enum WorkOrderStatus { assigned, inProgress, closed }

final class WorkOrder {
  final String id;
  final WorkOrderStatus status;
  const WorkOrder(this.id, this.status);
  bool get isOpen => status != WorkOrderStatus.closed;
}

abstract interface class WorkOrderRepository {
  Future<List<WorkOrder>> findOpen();
}

final class MemoryWorkOrderRepository implements WorkOrderRepository {
  final List<WorkOrder> _values;
  MemoryWorkOrderRepository(List<WorkOrder> values)
      : _values = List<WorkOrder>.unmodifiable(values);

  @override
  Future<List<WorkOrder>> findOpen() async => List<WorkOrder>.unmodifiable(
        _values.where((order) => order.isOpen),
      );
}

final class FakeWorkOrderRepository implements WorkOrderRepository {
  final List<WorkOrder> answer;
  final Object? failure;
  const FakeWorkOrderRepository({this.answer = const [], this.failure});

  @override
  Future<List<WorkOrder>> findOpen() async {
    if (failure case final Object problem) throw problem;
    return List<WorkOrder>.unmodifiable(answer);
  }
}

final class LoadOpenOrders {
  final WorkOrderRepository _repository;
  const LoadOpenOrders(this._repository);
  Future<List<WorkOrder>> call() => _repository.findOpen();
}

sealed class OrdersUiState {
  const OrdersUiState();
}

final class OrdersInitial extends OrdersUiState {
  const OrdersInitial();
}

final class OrdersLoading extends OrdersUiState {
  const OrdersLoading();
}

final class OrdersContent extends OrdersUiState {
  final List<WorkOrder> orders;
  OrdersContent(List<WorkOrder> orders)
      : orders = List<WorkOrder>.unmodifiable(orders);
}

final class OrdersEmpty extends OrdersUiState {
  const OrdersEmpty();
}

final class OrdersFailure extends OrdersUiState {
  final String diagnosticCode;
  const OrdersFailure(this.diagnosticCode);
}

final class OrdersController {
  final LoadOpenOrders _load;
  OrdersUiState _state = const OrdersInitial();
  final List<String> trace = <String>['initial'];
  OrdersController(this._load);
  OrdersUiState get state => _state;

  Future<void> refresh() async {
    _state = const OrdersLoading();
    trace.add('loading');
    try {
      final orders = await _load();
      _state = orders.isEmpty ? const OrdersEmpty() : OrdersContent(orders);
      trace.add(orders.isEmpty ? 'empty' : 'content');
    } catch (_) {
      _state = const OrdersFailure('ORDERS_LOAD_FAILED');
      trace.add('failure');
    }
  }
}

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
}

Future<void> main() async {
  var assertions = 0;
  void expect(bool condition, String label) {
    assertions++;
    check(condition, label);
  }

  const values = <WorkOrder>[
    WorkOrder('WO-1', WorkOrderStatus.assigned),
    WorkOrder('WO-2', WorkOrderStatus.closed),
  ];
  final memory = OrdersController(LoadOpenOrders(MemoryWorkOrderRepository(values)));
  final fake = OrdersController(LoadOpenOrders(const FakeWorkOrderRepository(answer: values)));
  await memory.refresh();
  await fake.refresh();
  expect(memory.state is OrdersContent, 'memory content state');
  expect(fake.state is OrdersContent, 'fake content state');
  expect((memory.state as OrdersContent).orders.single.id == 'WO-1', 'repository filters closed');
  expect((fake.state as OrdersContent).orders.map((e) => e.id).join(',') == 'WO-1,WO-2',
      'fake follows its declared answer');
  expect(memory.trace.join('>') == 'initial>loading>content', 'state transition trace');

  var immutable = false;
  try {
    (memory.state as OrdersContent).orders.add(const WorkOrder('WO-3', WorkOrderStatus.assigned));
  } on UnsupportedError {
    immutable = true;
  }
  expect(immutable, 'published UI state is immutable');

  final empty = OrdersController(LoadOpenOrders(const FakeWorkOrderRepository()));
  await empty.refresh();
  expect(empty.state is OrdersEmpty, 'empty is distinct from failure');
  final failed = OrdersController(
    LoadOpenOrders(FakeWorkOrderRepository(failure: StateError('offline'))),
  );
  await failed.refresh();
  expect(failed.state is OrdersFailure, 'failure is mapped to UI state');
  print('FLUTTER_ARCHITECTURE_EXAMPLE_PASS assertions=$assertions');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
