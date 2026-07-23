#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/lib/data" "$tmp_dir/lib/presentation"
cat >"$tmp_dir/lib/data/work_order_store.dart" <<'DART'
final class WorkOrderStore {
  List<String> loadOpenIds() => <String>['WO-1'];
}
DART

cat >"$tmp_dir/lib/presentation/orders_screen_model.dart" <<'DART'
// TODO: presentation 直接认识具体存储，无法替换边界。
import '../data/work_order_store.dart';

final class OrdersScreenModel {
  final WorkOrderStore store;
  const OrdersScreenModel(this.store);
  List<String> load() => store.loadOpenIds();
}
DART

cat >"$tmp_dir/main.dart" <<'DART'
import 'lib/data/work_order_store.dart';
import 'lib/presentation/orders_screen_model.dart';

void main() {
  final ids = OrdersScreenModel(WorkOrderStore()).load();
  if (ids.join(',') != 'WO-1') throw StateError('fixture');
}
DART

dart analyze "$tmp_dir"

if grep -Eq "^import .*data/" "$tmp_dir/lib/presentation/orders_screen_model.dart"; then
  echo "ARCHITECTURE_DEPENDENCY_EXERCISE source=presentation/orders_screen_model.dart forbidden=presentation-to-data expected=application-or-domain-port" >&2
  exit 41
fi

echo "unexpected green: dependency violation was not detected" >&2
exit 42
