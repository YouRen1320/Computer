from datetime import UTC, datetime

from solution import parse_instant

assert parse_instant("2026-07-24T10:00:00+08:00") == datetime(
    2026, 7, 24, 2, 0, tzinfo=UTC
)
for raw in ("2026-07-24T10:00:00", "not-a-time"):
    try:
        parse_instant(raw)
    except ValueError:
        continue
    raise AssertionError(f"expected ValueError for {raw}")
print("PASS files/json/time private solution")
