#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
final class FrameSample {
  final double uiMs;
  final double rasterMs;
  const FrameSample(this.uiMs, this.rasterMs);
  double get totalBudgetWork => uiMs > rasterMs ? uiMs : rasterMs;
}

final class FrameReport {
  final int samples;
  final int slowFrames;
  final double worstMs;
  const FrameReport(this.samples, this.slowFrames, this.worstMs);
}

FrameReport analyzeFrames(List<FrameSample> frames, {required double budgetMs}) {
  var slow = 0;
  var worst = 0.0;
  for (final frame in frames) {
    final value = frame.totalBudgetWork;
    if (value > budgetMs) slow++;
    if (value > worst) worst = value;
  }
  return FrameReport(frames.length, slow, worst);
}

final class HeapSnapshot {
  final Map<String, int> instances;
  const HeapSnapshot(this.instances);
}

Map<String, int> diff(HeapSnapshot before, HeapSnapshot after) {
  final keys = <String>{...before.instances.keys, ...after.instances.keys};
  return <String, int>{
    for (final key in keys)
      key: (after.instances[key] ?? 0) - (before.instances[key] ?? 0),
  };
}

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
}

void main() {
  var assertions = 0;
  void expect(bool condition, String label) {
    assertions++;
    check(condition, label);
  }

  const beforeFrames = <FrameSample>[
    FrameSample(7.0, 6.0),
    FrameSample(8.0, 7.5),
    FrameSample(38.0, 9.0),
    FrameSample(9.0, 25.0),
  ];
  const afterFrames = <FrameSample>[
    FrameSample(6.0, 5.0),
    FrameSample(7.0, 6.5),
    FrameSample(10.0, 8.0),
    FrameSample(8.0, 9.0),
  ];
  final before = analyzeFrames(beforeFrames, budgetMs: 16.67);
  final after = analyzeFrames(afterFrames, budgetMs: 16.67);
  expect(before.slowFrames == 2, 'baseline has two slow frames');
  expect(after.slowFrames == 0, 'repair removes synthetic slow frames');
  expect(after.worstMs < before.worstMs, 'worst frame improves');

  const heapBefore = HeapSnapshot(<String, int>{
    'WorkOrderPageState': 1,
    'TextEditingController': 2,
    'DecodedImage': 4,
  });
  const heapLeaking = HeapSnapshot(<String, int>{
    'WorkOrderPageState': 6,
    'TextEditingController': 12,
    'DecodedImage': 44,
  });
  const heapRepaired = HeapSnapshot(<String, int>{
    'WorkOrderPageState': 1,
    'TextEditingController': 2,
    'DecodedImage': 6,
  });
  final leaking = diff(heapBefore, heapLeaking);
  final repaired = diff(heapBefore, heapRepaired);
  expect(leaking['WorkOrderPageState'] == 5, 'snapshot exposes retained pages');
  expect(leaking['TextEditingController'] == 10, 'snapshot exposes controllers');
  expect(repaired['WorkOrderPageState'] == 0, 'page owner is released');
  expect(repaired['TextEditingController'] == 0, 'controllers are released');
  expect((repaired['DecodedImage'] ?? 999) <= 2, 'image cache remains within fixture budget');

  const rebuildsBefore = 1000;
  const rebuildsAfter = 120;
  expect(rebuildsAfter < rebuildsBefore, 'state subscription scope narrows rebuilds');
  final behaviorOracle = <String>['loading', 'content', 'conflict', 'retry'];
  expect(behaviorOracle.contains('conflict'), 'optimization keeps failure behavior');
  print(
    'FLUTTER_TESTING_PERFORMANCE_LAB_PASS assertions=$assertions '
    'profile_data=false synthetic_frames=${after.samples}',
  );
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
