abstract interface class WorkOrderReader {
  Future<List<String>> loadOpenIds();
}
