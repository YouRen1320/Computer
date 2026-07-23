#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
final class WorkOrder {
  final String id;
  const WorkOrder(this.id);
}

final class MemoryRepository {
  final Map<String, WorkOrder> _values = <String, WorkOrder>{};
  void save(WorkOrder order) => _values[order.id] = order;
  WorkOrder? findById(String id) => _values[id];
}

void main() {
  final first = MemoryRepository();
  final second = MemoryRepository();
  first.save(const WorkOrder('WO-1'));
  if (first.findById('WO-1')?.id != 'WO-1') throw StateError('save contract');
  if (second.findById('WO-1') != null) throw StateError('isolation contract');
  print('DART_OOP_GENERICS_SOLUTION_PASS assertions=2');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
