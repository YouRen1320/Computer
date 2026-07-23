#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
abstract interface class Entity {
  String get id;
}

final class WorkOrder implements Entity {
  @override
  final String id;
  final String title;
  final int priority;

  WorkOrder({required this.id, required String title, required this.priority})
      : title = title.trim() {
    if (!RegExp(r'^WO-[0-9]+$').hasMatch(id)) throw ArgumentError.value(id, 'id');
    if (this.title.isEmpty) throw ArgumentError.value(title, 'title');
    if (priority < 1 || priority > 5) {
      throw RangeError.range(priority, 1, 5, 'priority');
    }
  }
}

abstract interface class Repository<T extends Entity> {
  T? findById(String id);
  void save(T value);
}

final class MemoryRepository<T extends Entity> implements Repository<T> {
  final Map<String, T> _values = <String, T>{};
  @override
  T? findById(String id) => _values[id];
  @override
  void save(T value) => _values[value.id] = value;
}

mixin AuditStamp {
  String get actorId;
  String audit(String action) => '$actorId:$action';
}

final class AssignmentCommand with AuditStamp {
  @override
  final String actorId;
  final String orderId;
  AssignmentCommand(this.actorId, this.orderId);
}

extension WorkOrderIdText on String {
  bool get isWorkOrderId => RegExp(r'^WO-[0-9]+$').hasMatch(this);
}

void expect(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  var assertions = 0;
  void check(bool value, String label) {
    assertions++;
    expect(value, label);
  }

  final first = MemoryRepository<WorkOrder>();
  final second = MemoryRepository<WorkOrder>();
  final order = WorkOrder(id: 'WO-101', title: '  空压机异响  ', priority: 5);
  first.save(order);
  check(first.findById('WO-101') == order, 'saved entity');
  check(second.findById('WO-101') == null, 'instances are isolated');
  check(order.title == '空压机异响', 'constructor normalizes title');
  check(order.priority == 5, 'invariant value');
  check('WO-8'.isWorkOrderId, 'extension uses static String type');
  check(!'8'.isWorkOrderId, 'invalid id');
  check(AssignmentCommand('tech-7', order.id).audit('assign') == 'tech-7:assign', 'mixin contract');

  var rejected = false;
  try {
    WorkOrder(id: 'WO-102', title: 'x', priority: 0);
  } on RangeError {
    rejected = true;
  }
  check(rejected, 'invalid priority is rejected');
  print('DART_OOP_GENERICS_EXAMPLE_PASS assertions=$assertions');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
