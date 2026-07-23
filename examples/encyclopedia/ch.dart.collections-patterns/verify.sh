#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
typedef Ticket = ({String id, int priority, int? technicianId});
typedef Report = ({
  Map<int, List<String>> idsByTechnician,
  Set<String> uniqueIds,
  int urgentCount,
});

Report buildReport(List<Ticket> tickets) {
  final grouped = <int, List<String>>{};
  final ids = <String>{};
  var urgent = 0;
  for (final (:id, :priority, :technicianId) in tickets) {
    ids.add(id);
    if (priority >= 4) urgent++;
    if (technicianId case final int ownerId) {
      grouped.putIfAbsent(ownerId, () => <String>[]).add(id);
    }
  }
  return (
    idsByTechnician: Map.unmodifiable(<int, List<String>>{
      for (final MapEntry(:key, :value) in grouped.entries)
        key: List.unmodifiable(value),
    }),
    uniqueIds: Set.unmodifiable(ids),
    urgentCount: urgent,
  );
}

String shape(Object? value) => switch (value) {
  [final String first, ...final rest] => '$first:${rest.length}',
  {'id': final String id, 'priority': final int p} when p >= 4 => '$id:urgent',
  (:final int total, :final int urgent) => '$total/$urgent',
  _ => 'unknown',
};

void expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  var assertions = 0;
  void check(bool condition, String message) {
    assertions++;
    expect(condition, message);
  }

  final empty = buildReport(const <Ticket>[]);
  check(empty.idsByTechnician.isEmpty, 'empty grouping');
  check(empty.uniqueIds.isEmpty, 'empty set');
  check(empty.urgentCount == 0, 'empty urgent count');

  final report = buildReport(const <Ticket>[
    (id: 'WO-1', priority: 4, technicianId: 7),
    (id: 'WO-1', priority: 5, technicianId: 7),
    (id: 'WO-2', priority: 3, technicianId: null),
  ]);
  check(report.uniqueIds.length == 2, 'set must deduplicate ids');
  check(report.urgentCount == 2, 'urgent count follows input rows');
  check(report.idsByTechnician[7]!.join(',') == 'WO-1,WO-1', 'list keeps order and duplicates');
  check(shape(<String>['a', 'b', 'c']) == 'a:2', 'list pattern');
  check(shape(<String, Object>{'id': 'WO-9', 'priority': 5}) == 'WO-9:urgent', 'map pattern and guard');
  check(shape((total: 3, urgent: 2)) == '3/2', 'record pattern');

  var blocked = false;
  try {
    report.idsByTechnician[7]!.add('WO-3');
  } on UnsupportedError {
    blocked = true;
  }
  check(blocked, 'nested lists must be unmodifiable');
  print('DART_COLLECTIONS_PATTERNS_EXAMPLE_PASS assertions=$assertions');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
