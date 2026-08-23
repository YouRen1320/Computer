String? readAssigneeName() {
  return null;
}

void main() {
  final assigneeName = readAssigneeName();
  // TODO: 用 ?.、trim、toUpperCase 与 ?? 表达缺省值，不要强制解包。
  final normalized = assigneeName!.trim().toUpperCase();
  print('DART_TYPES_EXERCISE_PASS assignee=$normalized');
}
