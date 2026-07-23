#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
enum UiKind { denied, settingsRequired, failure }

final class NativeFailure {
  final String code;
  final String message;
  const NativeFailure(this.code, this.message);
}

final class UiFailure {
  final UiKind kind;
  final String userMessage;
  const UiFailure(this.kind, this.userMessage);
}

UiFailure mapFailure(NativeFailure failure) {
  // TODO: 永久拒绝不应再次请求；原始平台 message 也不能直接交给用户。
  if (failure.code == 'deniedForever') {
    return UiFailure(UiKind.denied, failure.message);
  }
  return UiFailure(UiKind.failure, failure.message);
}

void main() {
  const raw = NativeFailure(
    'deniedForever',
    'Camera denied; token=secret; path=/private/user/photo.jpg',
  );
  final mapped = mapFailure(raw);
  if (mapped.kind != UiKind.settingsRequired) {
    throw StateError('PERMISSION_MAPPING_EXERCISE expected=settingsRequired actual=${mapped.kind.name}');
  }
  if (mapped.userMessage.contains('token=') || mapped.userMessage.contains('/private/')) {
    throw StateError('PLATFORM_MESSAGE_LEAK_EXERCISE raw platform details reached UI');
  }
}
DART

dart analyze "$tmp_dir/main.dart"
set +e
output="$(dart run "$tmp_dir/main.dart" 2>&1)"
status=$?
set -e
if [[ $status -eq 0 ]]; then
  echo "unexpected green: exercise fault was not detected" >&2
  exit 42
fi
if [[ "$output" != *"PERMISSION_MAPPING_EXERCISE"* ]]; then
  echo "$output" >&2
  echo "unexpected failure: stable permission oracle was not reached" >&2
  exit 43
fi
echo "$output" >&2
echo "FLUTTER_DEVICE_APIS_EXERCISE_EXPECTED_RED fix=permission-state-and-error-redaction" >&2
exit 41
