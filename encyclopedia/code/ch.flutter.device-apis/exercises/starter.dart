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

UiFailure mapFailure(NativeFailure failure) {
  // TODO：按稳定 code 映射；不要把原始平台 message 直接展示给用户。
  return UiFailure(UiKind.denied, failure.code, failure.message);
}
