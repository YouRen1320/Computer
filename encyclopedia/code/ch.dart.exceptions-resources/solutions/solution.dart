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
  } finally {
    resource.close();
  }
}
