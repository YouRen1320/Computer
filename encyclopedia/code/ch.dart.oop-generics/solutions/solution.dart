abstract interface class Identified {
  String get id;
}

final class WorkOrder implements Identified {
  @override
  final String id;
  const WorkOrder(this.id);
}

final class MemoryRepository<T extends Identified> {
  final Map<String, T> _values = <String, T>{};

  void save(T value) => _values[value.id] = value;

  T? findById(String id) => _values[id];
}
