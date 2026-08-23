abstract interface class TicketPort {
  Future<void> save(String id);
}

final class DuplicateTicket implements Exception {
  const DuplicateTicket(this.id);
  final String id;
}

final class RepairService {
  const RepairService(this.port);
  final TicketPort port;

  Future<String> create(String id) async {
    if (id.trim().isEmpty) throw const FormatException('empty ticket id');
    await port.save(id);
    return id;
  }
}
