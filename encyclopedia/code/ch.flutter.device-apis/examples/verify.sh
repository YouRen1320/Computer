#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
enum PermissionState {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
}

enum RawPermission { granted, denied, deniedForever, restricted, unsupported }
enum DeviceFallback { none, manualEntry, openSettings }

sealed class DeviceResult {
  const DeviceResult();
}

final class DeviceReady extends DeviceResult {
  final String value;
  const DeviceReady(this.value);
}

final class DeviceDenied extends DeviceResult {
  final PermissionState permission;
  final DeviceFallback fallback;
  const DeviceDenied(this.permission, this.fallback);
}

final class DeviceUnavailable extends DeviceResult {
  final DeviceFallback fallback;
  const DeviceUnavailable(this.fallback);
}

final class DeviceCancelled extends DeviceResult {
  const DeviceCancelled();
}

PermissionState mapPermission(RawPermission raw) => switch (raw) {
      RawPermission.granted => PermissionState.granted,
      RawPermission.denied => PermissionState.denied,
      RawPermission.deniedForever => PermissionState.permanentlyDenied,
      RawPermission.restricted => PermissionState.restricted,
      RawPermission.unsupported => PermissionState.unavailable,
    };

DeviceResult decide({
  required RawPermission raw,
  required bool capabilityAvailable,
  required bool userCancelled,
  String? scannedValue,
}) {
  if (userCancelled) return const DeviceCancelled();
  final permission = mapPermission(raw);
  if (permission == PermissionState.permanentlyDenied) {
    return const DeviceDenied(
      PermissionState.permanentlyDenied,
      DeviceFallback.openSettings,
    );
  }
  if (permission != PermissionState.granted) {
    return DeviceDenied(permission, DeviceFallback.manualEntry);
  }
  if (!capabilityAvailable) {
    return const DeviceUnavailable(DeviceFallback.manualEntry);
  }
  final normalized = scannedValue?.trim() ?? '';
  if (!RegExp(r'^DEV-[0-9]{4}$').hasMatch(normalized)) {
    return const DeviceUnavailable(DeviceFallback.manualEntry);
  }
  return DeviceReady(normalized);
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

  final ready = decide(
    raw: RawPermission.granted,
    capabilityAvailable: true,
    userCancelled: false,
    scannedValue: ' DEV-0042 ',
  );
  expect(ready is DeviceReady, 'granted capability returns ready');
  expect((ready as DeviceReady).value == 'DEV-0042', 'candidate is normalized');

  final deniedForever = decide(
    raw: RawPermission.deniedForever,
    capabilityAvailable: true,
    userCancelled: false,
  );
  expect(deniedForever is DeviceDenied, 'permanent denial is explicit');
  expect(
    (deniedForever as DeviceDenied).fallback == DeviceFallback.openSettings,
    'permanent denial uses settings recovery',
  );

  final restricted = decide(
    raw: RawPermission.restricted,
    capabilityAvailable: true,
    userCancelled: false,
  );
  expect(
    restricted is DeviceDenied &&
        restricted.permission == PermissionState.restricted,
    'system restriction is not ordinary denial',
  );

  final unavailable = decide(
    raw: RawPermission.granted,
    capabilityAvailable: false,
    userCancelled: false,
  );
  expect(unavailable is DeviceUnavailable, 'hardware availability is separate');

  final cancelled = decide(
    raw: RawPermission.granted,
    capabilityAvailable: true,
    userCancelled: true,
  );
  expect(cancelled is DeviceCancelled, 'cancel is not a platform failure');

  final untrusted = decide(
    raw: RawPermission.granted,
    capabilityAvailable: true,
    userCancelled: false,
    scannedValue: 'https://attacker.example/internal',
  );
  expect(untrusted is DeviceUnavailable, 'scan remains untrusted input');
  print('FLUTTER_DEVICE_APIS_EXAMPLE_PASS assertions=$assertions real_device=false');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
