final class InvalidPriority implements Exception {
  const InvalidPriority(this.value);
  final int value;
}

final class WorkOrder {
  const WorkOrder({required this.id, required this.priority});
  final String id;
  final int priority;

  bool get isUrgent => priority >= 4;
}

WorkOrder parseWorkOrder(Map<String, Object?> input) {
  final id = input['id'];
  final priority = input['priority'];
  if (id is! String || id.isEmpty) throw const FormatException('invalid id');
  if (priority is! int || priority < 1 || priority > 5) {
    throw InvalidPriority(priority is int ? priority : -1);
  }
  return WorkOrder(id: id, priority: priority);
}

Future<WorkOrder> loadWorkOrder(Future<Map<String, Object?>> source) async =>
    parseWorkOrder(await source);
