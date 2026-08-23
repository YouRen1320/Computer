sealed class EditResult {
  const EditResult();
}

final class Saved extends EditResult {
  final String orderId;
  const Saved(this.orderId);
}

final class Cancelled extends EditResult {
  const Cancelled();
}

Object resultReturnedByPage({required bool saved, required String orderId}) =>
    saved ? Saved(orderId) : const Cancelled();

EditResult decodeResult(Object? raw) {
  if (raw is EditResult) return raw;
  throw FormatException('expected EditResult, got ${raw.runtimeType}');
}
