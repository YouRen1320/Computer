#!/usr/bin/env bash
set -euo pipefail
export DART_SUPPRESS_ANALYTICS=true
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/main.dart" <<'DART'
sealed class Result<T extends Object, E extends Object> {
  const Result();
}
final class Ok<T extends Object, E extends Object> extends Result<T, E> {
  final T value;
  const Ok(this.value);
}
final class Err<T extends Object, E extends Object> extends Result<T, E> {
  final E error;
  const Err(this.error);
}

final class TicketParseException implements Exception {
  final String field;
  const TicketParseException(this.field);
}
final class Ticket {
  final String id;
  final int priority;
  const Ticket(this.id, this.priority);
}
enum ImportFailure { invalidTicket }

abstract interface class SyncResource {
  String read();
  void close();
}
final class RecordingResource implements SyncResource {
  final String value;
  final bool failRead;
  final String name;
  final List<String>? events;
  int closeCount = 0;
  RecordingResource(this.value, {this.failRead = false, this.name = 'resource', this.events});
  @override
  String read() {
    if (failRead) throw StateError('read failed');
    return value;
  }
  @override
  void close() {
    closeCount++;
    events?.add('close-$name');
  }
}

Ticket parseTicket(String raw) {
  final parts = raw.split(',');
  if (parts.length != 2) throw const TicketParseException('payload');
  final id = parts[0];
  final priority = int.tryParse(parts[1]);
  if (!RegExp(r'^WO-[0-9]+$').hasMatch(id)) throw const TicketParseException('id');
  if (priority == null || priority < 1 || priority > 5) {
    throw const TicketParseException('priority');
  }
  return Ticket(id, priority);
}

Result<Ticket, ImportFailure> importFrom(SyncResource resource) {
  try {
    try {
      return Ok<Ticket, ImportFailure>(parseTicket(resource.read()));
    } on TicketParseException {
      return const Err<Ticket, ImportFailure>(ImportFailure.invalidTicket);
    }
  } finally {
    resource.close();
  }
}

void useTwo(RecordingResource first, RecordingResource second) {
  try {
    try {
      first.read();
      second.read();
    } finally {
      second.close();
    }
  } finally {
    first.close();
  }
}

void expect(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  var assertions = 0;
  void check(bool value, String label) {
    assertions++;
    expect(value, label);
  }

  final good = RecordingResource('WO-10,4');
  final goodResult = importFrom(good);
  check(goodResult is Ok<Ticket, ImportFailure>, 'valid input is Ok');
  check((goodResult as Ok<Ticket, ImportFailure>).value.id == 'WO-10', 'parsed id');
  check(good.closeCount == 1, 'valid cleanup');

  final invalid = RecordingResource('WO-10,bad');
  check(importFrom(invalid) is Err<Ticket, ImportFailure>, 'invalid input is Err');
  check(invalid.closeCount == 1, 'invalid cleanup');

  final broken = RecordingResource('unused', failRead: true);
  Object? error;
  StackTrace? stack;
  try {
    importFrom(broken);
  } catch (caught, caughtStack) {
    error = caught;
    stack = caughtStack;
  }
  check(error is StateError, 'unknown read error propagates');
  check(stack != null && stack.toString().contains('read'), 'stack evidence');
  check(broken.closeCount == 1, 'read failure cleanup');

  final events = <String>[];
  final first = RecordingResource('a', name: 'a', events: events);
  final second = RecordingResource('b', name: 'b', events: events);
  useTwo(first, second);
  check(events.join(',') == 'close-b,close-a', 'reverse cleanup order');
  check(first.closeCount == 1 && second.closeCount == 1, 'each resource closes once');
  print('DART_EXCEPTIONS_RESOURCES_LAB_PASS assertions=$assertions faults=3');
}
DART

dart analyze "$tmp_dir/main.dart"
dart run "$tmp_dir/main.dart"
