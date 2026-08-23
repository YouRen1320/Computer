"""Verify laziness, exhaustion, metadata and exception transparency."""

from __future__ import annotations

import inspect
import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from example import active, label  # noqa: E402


trace: list[str] = []
iterator = active(["ASSIGNED", "CLOSED", "IN_PROGRESS"], trace)
assert trace == []
assert next(iterator) == "ASSIGNED"
assert trace == ["started", "seen:ASSIGNED"]
assert list(iterator) == ["IN_PROGRESS"]
assert list(iterator) == []
assert trace[-1] == "finished"
assert label(7, status="CLOSED") == "7:CLOSED"
assert label.__name__ == "label" and label.__doc__ == "Render an order label."
assert str(inspect.signature(label)) == "(order_id: 'int', *, status: 'str') -> 'str'"
try:
    label(-1, status="CLOSED")
except ValueError as error:
    assert str(error) == "negative id"
else:
    raise AssertionError("decorator swallowed exception")
print("PASS: laziness, exhaustion and decorator transparency")
