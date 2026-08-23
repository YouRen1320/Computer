import 'dart:io';

import 'starter.dart';

void main() {
  final problems = <String>[];
  final first = MemoryRepository<WorkOrder>();
  final second = MemoryRepository<WorkOrder>();

  first.save(const WorkOrder('WO-1'));
  if (first.findById('WO-1')?.id != 'WO-1') problems.add('save-read-contract');
  if (second.findById('WO-1') != null) problems.add('instance-state-leaked');

  second.save(const WorkOrder('WO-2'));
  if (first.findById('WO-2') != null)
    problems.add('reverse-instance-state-leaked');

  if (problems.isNotEmpty) {
    stderr.writeln(
      'EXPECTED_DART_OOP_GENERICS_RED problems=${problems.join(',')}',
    );
    exitCode = 1;
    return;
  }
  print('DART_OOP_GENERICS_EXERCISE_PASS checks=3');
}
