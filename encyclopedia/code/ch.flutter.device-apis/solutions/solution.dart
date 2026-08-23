enum UiKind { denied, settingsRequired, failure }

final class NativeFailure {
  final String code;
  final String message;
  const NativeFailure(this.code, this.message);
}

final class UiFailure {
  final UiKind kind;
  final String diagnosticCode;
  final String userMessage;
  const UiFailure(this.kind, this.diagnosticCode, this.userMessage);
}

UiFailure mapFailure(NativeFailure failure) => switch (failure.code) {
  'denied' => const UiFailure(
    UiKind.denied,
    'CAMERA_DENIED',
    '未获得相机权限，可稍后再次尝试。',
  ),
  'deniedForever' => const UiFailure(
    UiKind.settingsRequired,
    'CAMERA_SETTINGS_REQUIRED',
    '请在系统设置中允许相机访问，返回后将重新检查。',
  ),
  _ => const UiFailure(
    UiKind.failure,
    'DEVICE_PLATFORM_FAILURE',
    '设备能力暂时不可用，请稍后重试。',
  ),
};
