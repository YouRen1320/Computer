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
  final int priority;
  WorkOrder(this.id, this.priority) {
    if (!id.startsWith('WO-')) throw ArgumentError.value(id, 'id');
    if (priority < 1 || priority > 5) throw RangeError.range(priority, 1, 5);
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

final class FixedRepository<T extends Entity> implements Repository<T> {
  final T? fixed;
  FixedRepository(this.fixed);
  @override
  T? findById(String id) => fixed?.id == id ? fixed : null;
  @override
  void save(T value) => throw UnsupportedError('read-only fake');
}

sealed class LoadResult<T extends Object> {
  const LoadResult();
}
final class Loaded<T extends Object> extends LoadResult<T> {
  final T value;
  const Loaded(this.value);
}
final class Missing<T extends Object> extends LoadResult<T> {
  final String id;
  const Missing(this.id);
}

LoadResult<T> load<T extends Entity>(Repository<T> repository, String id) {
  final value = repository.findById(id);
  return value == null ? Missing<T>(id) : Loaded<T>(value);
}

String describe(LoadResult<WorkOrder> result) => switch (result) {
  Loaded<WorkOrder>(:final value) => 'loaded:${value.id}',
  Missing<WorkOrder>(:final id) => 'missing:$id',
};

void check(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  var assertions = 0;
  void expect(bool value, String label) {
    assertions++;
    check(value, label);
  }

  final order = WorkOrder('WO-1', 4);
  final memory = MemoryRepository<WorkOrder>()..save(order);
  final fixed = FixedRepository<WorkOrder>(order);
  expect(describe(load(memory, 'WO-1')) == 'loaded:WO-1', 'memory substitution');
  expect(describe(load(fixed, 'WO-1')) == 'loaded:WO-1', 'fake substitution');
  expect(describe(load(memory, 'WO-9')) == 'missing:WO-9', 'missing result');
  final isolated = MemoryRepository<WorkOrder>();
  expect(describe(load(isolated, 'WO-1')) == 'missing:WO-1', 'instance isolation');

  var badId = false;
  try {
    WorkOrder('bad', 4);
  } on ArgumentError {
    badId = true;
  }
  expect(badId, 'id invariant');
  var badPriority = false;
  try {
    WorkOrder('WO-2', 6);
  } on RangeError {
    badPriority = true;
  }
  expect(badPriority, 'priority invariant');
  print('DART_OOP_GENERICS_LAB_PASS assertions=$assertions faults=3');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
