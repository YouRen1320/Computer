import 'package:dart_testing_lints_lab/repair_service.dart';
import 'package:test/test.dart';

final class FakeTicketPort implements TicketPort {
  final Set<String> saved = {};
  final List<String> calls = [];

  @override
  Future<void> save(String id) async {
    calls.add(id);
    if (!saved.add(id)) throw DuplicateTicket(id);
  }
}

void main() {
  late FakeTicketPort port;
  late RepairService service;

  setUp(() {
    port = FakeTicketPort();
    service = RepairService(port);
  });

  test('creates one ticket and records one observable call', () async {
    expect(await service.create('WO-1'), equals('WO-1'));
    expect(port.calls, equals(['WO-1']));
  });

  test('each test receives a fresh fake', () {
    expect(port.saved, isEmpty);
    expect(port.calls, isEmpty);
  });

  test('duplicate failure preserves the domain id', () async {
    await service.create('WO-2');
    await expectLater(
      service.create('WO-2'),
      throwsA(isA<DuplicateTicket>().having((error) => error.id, 'id', 'WO-2')),
    );
  });

  test('invalid input never reaches the port', () async {
    await expectLater(service.create('  '), throwsA(isA<FormatException>()));
    expect(port.calls, isEmpty);
  });
}
