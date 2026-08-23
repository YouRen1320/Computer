from datetime import UTC, datetime

from starter import parse_instant

assert parse_instant("2026-07-24T10:00:00+08:00") == datetime(
    2026, 7, 24, 2, 0, tzinfo=UTC
)
try:
    parse_instant("2026-07-24T10:00:00")
except ValueError:
    pass
else:
    raise AssertionError("naive timestamp must be rejected; complete TODO")
print("PASS files/json/time public exercise")
