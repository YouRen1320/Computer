#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
typedef Ticket = ({String id, String status, int? technicianId});
typedef Summary = ({Map<int, List<String>> grouped, Set<String> ids, int open});

Summary summarize(List<Ticket> source) {
  final grouped = <int, List<String>>{};
  final ids = <String>{};
  var open = 0;
  for (final ticket in source) {
    ids.add(ticket.id);
    if (ticket.status != 'CLOSED' && ticket.status != 'CANCELLED') open++;
    if (ticket.technicianId case final int owner) {
      grouped.putIfAbsent(owner, () => <String>[]).add(ticket.id);
    }
  }
  return (
    grouped: Map.unmodifiable(<int, List<String>>{
      for (final entry in grouped.entries)
        entry.key: List.unmodifiable(<String>[...entry.value]),
    }),
    ids: Set.unmodifiable(<String>{...ids}),
    open: open,
  );
}

void check(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  var assertions = 0;
  void expect(bool value, String label) {
    assertions++;
    check(value, label);
  }

  final input = <Ticket>[
    (id: 'WO-10', status: 'IN_PROGRESS', technicianId: 2),
    (id: 'WO-11', status: 'CLOSED', technicianId: 2),
    (id: 'WO-10', status: 'ASSIGNED', technicianId: 3),
    (id: 'WO-12', status: 'CANCELLED', technicianId: null),
  ];
  final result = summarize(input);
  expect(result.ids.length == 3, 'duplicate ids are unique in set');
  expect(result.open == 2, 'open rows follow status rule');
  expect(result.grouped[2]!.join('|') == 'WO-10|WO-11', 'group order');
  expect(result.grouped[3]!.single == 'WO-10', 'second technician');

  input.add((id: 'WO-99', status: 'ASSIGNED', technicianId: 2));
  expect(!result.ids.contains('WO-99'), 'result owns a snapshot');
  expect(!result.grouped[2]!.contains('WO-99'), 'nested list does not alias input');

  final (:grouped, :ids, :open) = result;
  expect(grouped.length == 2 && ids.length == 3 && open == 2, 'record destructuring');
  final label = switch (result) {
    (:final int open, :final Set<String> ids, :final Map<int, List<String>> grouped)
        when open > 0 && grouped.isNotEmpty => 'active:${ids.length}',
    _ => 'empty',
  };
  expect(label == 'active:3', 'record pattern guard');
  print('DART_COLLECTIONS_PATTERNS_LAB_PASS assertions=$assertions faults=3');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
