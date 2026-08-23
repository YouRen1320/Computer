abstract interface class Identified {
  String get id;
}

final class WorkOrder implements Identified {
  @override
  final String id;
  const WorkOrder(this.id);
}

final class MemoryRepository<T extends Identified> {
  // TODO：static 让所有实例共享状态，破坏仓储实例的所有权边界。
  static final Map<String, Identified> _shared = <String, Identified>{};

  void save(T value) => _shared[value.id] = value;

  T? findById(String id) => _shared[id] as T?;
}
