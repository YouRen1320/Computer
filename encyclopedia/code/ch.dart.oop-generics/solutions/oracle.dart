import 'solution.dart';

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
}

void main() {
  final first = MemoryRepository<WorkOrder>();
  final second = MemoryRepository<WorkOrder>();
  first.save(const WorkOrder('WO-1'));
  check(first.findById('WO-1')?.id == 'WO-1', 'save/read');
  check(second.findById('WO-1') == null, 'instance isolation');
  second.save(const WorkOrder('WO-2'));
  check(first.findById('WO-2') == null, 'reverse isolation');
  print('DART_OOP_GENERICS_SOLUTION_PASS checks=3');
}
