#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/lib/domain" "$tmp_dir/lib/application" "$tmp_dir/lib/data" "$tmp_dir/lib/presentation"

cat >"$tmp_dir/lib/domain/work_order.dart" <<'DART'
enum WorkOrderStatus { assigned, inProgress, closed }

final class WorkOrder {
  final String id;
  final WorkOrderStatus status;
  const WorkOrder(this.id, this.status);
  bool get isOpen => status != WorkOrderStatus.closed;
}
DART

cat >"$tmp_dir/lib/domain/work_order_repository.dart" <<'DART'
import 'work_order.dart';

final class RepositoryUnavailable implements Exception {
  const RepositoryUnavailable();
}

abstract interface class WorkOrderRepository {
  Future<List<WorkOrder>> findOpen();
}
DART

cat >"$tmp_dir/lib/application/load_open_orders.dart" <<'DART'
import '../domain/work_order.dart';
import '../domain/work_order_repository.dart';

final class LoadOpenOrders {
  final WorkOrderRepository _repository;
  const LoadOpenOrders(this._repository);
  Future<List<WorkOrder>> call() => _repository.findOpen();
}
DART

cat >"$tmp_dir/lib/data/fake_work_order_repository.dart" <<'DART'
import '../domain/work_order.dart';
import '../domain/work_order_repository.dart';

final class FakeWorkOrderRepository implements WorkOrderRepository {
  List<WorkOrder> values;
  Object? nextFailure;
  FakeWorkOrderRepository(this.values);

  @override
  Future<List<WorkOrder>> findOpen() async {
    final failure = nextFailure;
    nextFailure = null;
    if (failure != null) throw failure;
    return List<WorkOrder>.unmodifiable(values.where((order) => order.isOpen));
  }
}
DART

cat >"$tmp_dir/lib/presentation/orders_controller.dart" <<'DART'
import '../application/load_open_orders.dart';
import '../domain/work_order.dart';
import '../domain/work_order_repository.dart';

sealed class OrdersUiState {
  const OrdersUiState();
}
final class OrdersInitial extends OrdersUiState { const OrdersInitial(); }
final class OrdersLoading extends OrdersUiState { const OrdersLoading(); }
final class OrdersContent extends OrdersUiState {
  final List<WorkOrder> orders;
  final bool refreshing;
  OrdersContent(List<WorkOrder> orders, {this.refreshing = false})
      : orders = List<WorkOrder>.unmodifiable(orders);
}
final class OrdersEmpty extends OrdersUiState { const OrdersEmpty(); }
final class OrdersFailure extends OrdersUiState {
  final String diagnosticCode;
  final List<WorkOrder> staleOrders;
  OrdersFailure(this.diagnosticCode, {List<WorkOrder> staleOrders = const []})
      : staleOrders = List<WorkOrder>.unmodifiable(staleOrders);
}

final class OrdersController {
  final LoadOpenOrders _load;
  OrdersUiState _state = const OrdersInitial();
  final List<String> trace = <String>['initial'];
  OrdersController(this._load);
  OrdersUiState get state => _state;

  Future<void> refresh() async {
    final previous = _state is OrdersContent
        ? (_state as OrdersContent).orders
        : const <WorkOrder>[];
    _state = previous.isEmpty
        ? const OrdersLoading()
        : OrdersContent(previous, refreshing: true);
    trace.add(previous.isEmpty ? 'loading' : 'refreshing');
    try {
      final values = await _load();
      _state = values.isEmpty ? const OrdersEmpty() : OrdersContent(values);
      trace.add(values.isEmpty ? 'empty' : 'content');
    } on RepositoryUnavailable {
      _state = OrdersFailure('REPOSITORY_UNAVAILABLE', staleOrders: previous);
      trace.add(previous.isEmpty ? 'failure' : 'stale-failure');
    }
  }
}
DART

cat >"$tmp_dir/main.dart" <<'DART'
import 'lib/application/load_open_orders.dart';
import 'lib/data/fake_work_order_repository.dart';
import 'lib/domain/work_order.dart';
import 'lib/domain/work_order_repository.dart';
import 'lib/presentation/orders_controller.dart';

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
}

Future<void> main() async {
  var assertions = 0;
  void expect(bool condition, String label) {
    assertions++;
    check(condition, label);
  }

  final fake = FakeWorkOrderRepository(<WorkOrder>[
    const WorkOrder('WO-1', WorkOrderStatus.assigned),
    const WorkOrder('WO-2', WorkOrderStatus.closed),
  ]);
  final controller = OrdersController(LoadOpenOrders(fake));
  await controller.refresh();
  expect(controller.state is OrdersContent, 'success gives content');
  expect((controller.state as OrdersContent).orders.single.id == 'WO-1', 'closed is filtered');
  expect(controller.trace.join('>') == 'initial>loading>content', 'initial transition');

  fake.nextFailure = const RepositoryUnavailable();
  await controller.refresh();
  expect(controller.state is OrdersFailure, 'refresh failure is explicit');
  expect((controller.state as OrdersFailure).staleOrders.single.id == 'WO-1', 'stale data retained');
  expect(controller.trace.last == 'stale-failure', 'stale failure trace');

  final empty = OrdersController(LoadOpenOrders(FakeWorkOrderRepository(<WorkOrder>[])));
  await empty.refresh();
  expect(empty.state is OrdersEmpty, 'empty is not an error');

  final failed = FakeWorkOrderRepository(<WorkOrder>[])..nextFailure = const RepositoryUnavailable();
  final firstFailure = OrdersController(LoadOpenOrders(failed));
  await firstFailure.refresh();
  expect(firstFailure.state is OrdersFailure, 'first load failure');

  var immutable = false;
  try {
    (controller.state as OrdersFailure).staleOrders.clear();
  } on UnsupportedError {
    immutable = true;
  }
  expect(immutable, 'failure snapshot is immutable');
  print('FLUTTER_ARCHITECTURE_LAB_RUNTIME_PASS assertions=$assertions');
}
DART

edges=0
while IFS= read -r -d '' file; do
  relative="${file#"$tmp_dir/lib/"}"
  case "$relative" in
    domain/*)
      if grep -Eq "^import .*(application|presentation|data)/|^import .*package:flutter" "$file"; then
        echo "ARCHITECTURE_RULE_FAILURE source=$relative allowed=domain-only" >&2
        exit 31
      fi
      ;;
    application/*)
      if grep -Eq "^import .*(presentation|data)/|^import .*package:flutter" "$file"; then
        echo "ARCHITECTURE_RULE_FAILURE source=$relative allowed=domain" >&2
        exit 32
      fi
      ;;
    presentation/*)
      if grep -Eq "^import .*data/" "$file"; then
        echo "ARCHITECTURE_RULE_FAILURE source=$relative forbidden=presentation-to-data" >&2
        exit 33
      fi
      ;;
    data/*)
      if grep -Eq "^import .*(presentation|application)/" "$file"; then
        echo "ARCHITECTURE_RULE_FAILURE source=$relative forbidden=data-to-outer-layer" >&2
        exit 34
      fi
      ;;
  esac
  count="$(grep -Ec '^import ' "$file" || true)"
  edges=$((edges + count))
done < <(find "$tmp_dir/lib" -name '*.dart' -print0)

dart analyze "$tmp_dir"
dart run "$tmp_dir/main.dart"
echo "FLUTTER_ARCHITECTURE_LAB_PASS dependency_edges=$edges"
