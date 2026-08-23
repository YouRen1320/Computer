#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
import 'dart:async';

enum PermissionState { granted, denied, permanentlyDenied, restricted, unavailable }
enum DeviceUiKind { idle, active, success, denied, settingsRequired, unavailable, failure }

final class PlatformReply {
  final String kind;
  final String? value;
  final String? rawMessage;
  const PlatformReply(this.kind, {this.value, this.rawMessage});
}

final class DeviceUiState {
  final DeviceUiKind kind;
  final String diagnosticCode;
  final String? value;
  const DeviceUiState(this.kind, this.diagnosticCode, {this.value});
}

abstract interface class DevicePort {
  Future<PlatformReply> scan(String requestId);
  void cancel(String requestId);
}

final class PendingCall {
  final String requestId;
  final Completer<PlatformReply> completer = Completer<PlatformReply>();
  PendingCall(this.requestId);
}

final class FakeDevicePort implements DevicePort {
  final List<PendingCall> calls = <PendingCall>[];
  final List<String> cancelled = <String>[];

  @override
  Future<PlatformReply> scan(String requestId) {
    final call = PendingCall(requestId);
    calls.add(call);
    return call.completer.future;
  }

  @override
  void cancel(String requestId) => cancelled.add(requestId);
}

DeviceUiState mapReply(PlatformReply reply) => switch (reply.kind) {
      'success' => DeviceUiState(
          DeviceUiKind.success,
          'SCAN_OK',
          value: reply.value,
        ),
      'denied' => const DeviceUiState(DeviceUiKind.denied, 'CAMERA_DENIED'),
      'deniedForever' => const DeviceUiState(
          DeviceUiKind.settingsRequired,
          'CAMERA_SETTINGS_REQUIRED',
        ),
      'restricted' => const DeviceUiState(DeviceUiKind.denied, 'CAMERA_RESTRICTED'),
      'unavailable' => const DeviceUiState(
          DeviceUiKind.unavailable,
          'CAMERA_UNAVAILABLE',
        ),
      _ => const DeviceUiState(DeviceUiKind.failure, 'DEVICE_PLATFORM_FAILURE'),
    };

final class DeviceController {
  final DevicePort _port;
  int _generation = 0;
  String? _activeId;
  bool _closed = false;
  DeviceUiState state = const DeviceUiState(DeviceUiKind.idle, 'IDLE');
  final List<String> trace = <String>[];
  DeviceController(this._port);

  Future<void> scan() async {
    final previous = _activeId;
    if (previous != null) _port.cancel(previous);
    final id = 'scan-${++_generation}';
    _activeId = id;
    state = const DeviceUiState(DeviceUiKind.active, 'SCAN_ACTIVE');
    trace.add('start:$id');
    final reply = await _port.scan(id);
    if (_closed || _activeId != id) {
      trace.add('ignored:$id');
      return;
    }
    state = mapReply(reply);
    trace.add('result:$id:${state.diagnosticCode}');
  }

  void close() {
    _closed = true;
    final id = _activeId;
    if (id != null) _port.cancel(id);
    _activeId = null;
  }
}

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
}

Future<void> main() async {
  var assertions = 0;
  void expect(bool condition, String label) {
    assertions++;
    check(condition, label);
  }

  final fake = FakeDevicePort();
  final controller = DeviceController(fake);
  final first = controller.scan();
  final second = controller.scan();
  expect(fake.cancelled.single == 'scan-1', 'new request cancels prior session');
  fake.calls[1].completer.complete(
    const PlatformReply('success', value: 'DEV-0042'),
  );
  await second;
  expect(controller.state.kind == DeviceUiKind.success, 'latest result wins');
  fake.calls[0].completer.complete(const PlatformReply('deniedForever'));
  await first;
  expect(controller.state.kind == DeviceUiKind.success, 'late result is ignored');
  expect(controller.trace.contains('ignored:scan-1'), 'late evidence is recorded');

  final permissionCases = <String, DeviceUiKind>{
    'denied': DeviceUiKind.denied,
    'deniedForever': DeviceUiKind.settingsRequired,
    'restricted': DeviceUiKind.denied,
    'unavailable': DeviceUiKind.unavailable,
    'unknown-native-code': DeviceUiKind.failure,
  };
  for (final entry in permissionCases.entries) {
    expect(mapReply(PlatformReply(entry.key)).kind == entry.value, 'matrix ${entry.key}');
  }
  final unknown = mapReply(
    const PlatformReply('unknown-native-code', rawMessage: 'token=/private/path'),
  );
  expect(unknown.diagnosticCode == 'DEVICE_PLATFORM_FAILURE', 'raw message is not leaked');

  final closedFake = FakeDevicePort();
  final closed = DeviceController(closedFake);
  final pending = closed.scan();
  closed.close();
  closedFake.calls.single.completer.complete(
    const PlatformReply('success', value: 'DEV-9999'),
  );
  await pending;
  expect(closed.state.kind == DeviceUiKind.active, 'closed owner does not publish late UI');
  expect(closedFake.cancelled.contains('scan-1'), 'close forwards cancellation');
  print('FLUTTER_DEVICE_APIS_LAB_PASS assertions=$assertions real_device=false');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
