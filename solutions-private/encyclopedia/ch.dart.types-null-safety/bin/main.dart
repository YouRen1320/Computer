String? readAssigneeName() {
  return null;
}

void main() {
  final assigneeName = readAssigneeName();
  final normalized = assigneeName?.trim().toUpperCase() ?? 'UNASSIGNED';
  print('DART_TYPES_SOLUTION_PASS assignee=$normalized');
}
