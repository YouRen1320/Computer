import '../domain/work_order_reader.dart';

final class MemoryWorkOrderReader implements WorkOrderReader {
  final List<String> ids;

  MemoryWorkOrderReader(List<String> ids)
    : ids = List<String>.unmodifiable(ids);

  @override
  Future<List<String>> loadOpenIds() async => ids;
}
