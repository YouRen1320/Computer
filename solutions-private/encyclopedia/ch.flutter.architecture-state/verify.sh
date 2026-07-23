#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/lib/domain" "$tmp_dir/lib/data" "$tmp_dir/lib/presentation"
cat >"$tmp_dir/lib/domain/work_order_reader.dart" <<'DART'
abstract interface class WorkOrderReader {
  Future<List<String>> loadOpenIds();
}
DART

cat >"$tmp_dir/lib/data/memory_work_order_reader.dart" <<'DART'
import '../domain/work_order_reader.dart';

final class MemoryWorkOrderReader implements WorkOrderReader {
  final List<String> ids;
  MemoryWorkOrderReader(List<String> ids) : ids = List<String>.unmodifiable(ids);
  @override
  Future<List<String>> loadOpenIds() async => ids;
}
DART

cat >"$tmp_dir/lib/presentation/orders_controller.dart" <<'DART'
import '../domain/work_order_reader.dart';

sealed class OrdersState { const OrdersState(); }
final class OrdersInitial extends OrdersState { const OrdersInitial(); }
final class OrdersContent extends OrdersState {
  final List<String> ids;
  OrdersContent(List<String> ids) : ids = List<String>.unmodifiable(ids);
}

final class OrdersController {
  final WorkOrderReader _reader;
  OrdersState state = const OrdersInitial();
  OrdersController(this._reader);
  Future<void> load() async => state = OrdersContent(await _reader.loadOpenIds());
}
DART

cat >"$tmp_dir/main.dart" <<'DART'
import 'lib/data/memory_work_order_reader.dart';
import 'lib/domain/work_order_reader.dart';
import 'lib/presentation/orders_controller.dart';

final class FakeWorkOrderReader implements WorkOrderReader {
  @override
  Future<List<String>> loadOpenIds() async => <String>['WO-FAKE'];
}

Future<void> main() async {
  final real = OrdersController(MemoryWorkOrderReader(<String>['WO-1']));
  final fake = OrdersController(FakeWorkOrderReader());
  await real.load();
  await fake.load();
  if ((real.state as OrdersContent).ids.single != 'WO-1') throw StateError('real substitution');
  if ((fake.state as OrdersContent).ids.single != 'WO-FAKE') throw StateError('fake substitution');
  print('FLUTTER_ARCHITECTURE_SOLUTION_PASS assertions=2');
}
DART

if grep -Eq "^import .*data/" "$tmp_dir/lib/presentation/orders_controller.dart"; then
  echo "ARCHITECTURE_RULE_FAILURE presentation imports data" >&2
  exit 51
fi
if grep -Eq "^import .*(presentation|data)/|^import .*package:flutter" "$tmp_dir/lib/domain/work_order_reader.dart"; then
  echo "ARCHITECTURE_RULE_FAILURE domain imports outer layer" >&2
  exit 52
fi

dart analyze "$tmp_dir"
dart run "$tmp_dir/main.dart"
