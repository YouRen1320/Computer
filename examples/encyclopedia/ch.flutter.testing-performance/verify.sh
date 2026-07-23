#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
enum TestLayer { unit, widget, integration, golden, deviceSmoke }

enum Risk {
  stateTransition,
  loadingSemantics,
  routeAndPersistence,
  pixelOverflow,
  nativePermissionDialog,
}

TestLayer minimumLayer(Risk risk) => switch (risk) {
      Risk.stateTransition => TestLayer.unit,
      Risk.loadingSemantics => TestLayer.widget,
      Risk.routeAndPersistence => TestLayer.integration,
      Risk.pixelOverflow => TestLayer.golden,
      Risk.nativePermissionDialog => TestLayer.deviceSmoke,
    };

final class GoldenFingerprint {
  final String flutter;
  final String os;
  final String fontSha;
  final String locale;
  final String surface;
  const GoldenFingerprint({
    required this.flutter,
    required this.os,
    required this.fontSha,
    required this.locale,
    required this.surface,
  });

  bool sameEnvironment(GoldenFingerprint other) =>
      flutter == other.flutter &&
      os == other.os &&
      fontSha == other.fontSha &&
      locale == other.locale &&
      surface == other.surface;
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

  expect(minimumLayer(Risk.stateTransition) == TestLayer.unit, 'pure state uses unit');
  expect(minimumLayer(Risk.loadingSemantics) == TestLayer.widget, 'semantics needs widget');
  expect(
    minimumLayer(Risk.routeAndPersistence) == TestLayer.integration,
    'composition needs integration',
  );
  expect(minimumLayer(Risk.pixelOverflow) == TestLayer.golden, 'pixels need golden');
  expect(
    minimumLayer(Risk.nativePermissionDialog) == TestLayer.deviceSmoke,
    'native UI is outside ordinary widget tests',
  );

  const baseline = GoldenFingerprint(
    flutter: '3.44.x',
    os: 'fixed-runner',
    fontSha: 'font-sha-001',
    locale: 'zh_CN',
    surface: '390x844@3',
  );
  const same = GoldenFingerprint(
    flutter: '3.44.x',
    os: 'fixed-runner',
    fontSha: 'font-sha-001',
    locale: 'zh_CN',
    surface: '390x844@3',
  );
  const drifted = GoldenFingerprint(
    flutter: '3.44.x',
    os: 'fixed-runner',
    fontSha: 'font-sha-999',
    locale: 'zh_CN',
    surface: '390x844@3',
  );
  expect(baseline.sameEnvironment(same), 'same fingerprint may compare pixels');
  expect(!baseline.sameEnvironment(drifted), 'font drift blocks golden comparison');
  print('FLUTTER_TESTING_EXAMPLE_PASS assertions=$assertions flutter_runtime=false');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
