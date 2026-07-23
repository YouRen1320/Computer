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
  // TODO: static 让所有 repository 实例共享状态，破坏实例边界。
  static final Map<String, WorkOrder> _values = <String, WorkOrder>{};
  void save(WorkOrder order) => _values[order.id] = order;
  WorkOrder? findById(String id) => _values[id];
}

void main() {
  final first = MemoryRepository();
  final second = MemoryRepository();
  first.save(const WorkOrder('WO-1'));
  final leaked = second.findById('WO-1');
  print('SHARED_STATIC_STATE_EXERCISE expected=null actual=${leaked?.id}');
  if (leaked != null) throw StateError('repository instances must be isolated');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
