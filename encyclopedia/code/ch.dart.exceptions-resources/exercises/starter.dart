final class Resource {
  final String? value;
  final StateError? failure;
  int closeCount = 0;

  Resource.success(this.value) : failure = null;
  Resource.failure(this.failure) : value = null;

  String read() {
    if (failure case final error?) throw error;
    return value!;
  }

  void close() => closeCount++;
}

String importSafely(Resource resource) {
  try {
    return resource.read();
  } catch (_) {
    // TODO：不要吞掉未知失败，并确保所有路径都只关闭一次。
    return '';
  }
}
