"""Verify cleanup for early close and natural exhaustion."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from lab import values  # noqa: E402


early: list[str] = []
iterator = values(early)
assert early == []
assert next(iterator) == 1
iterator.close()
assert early == ["open", "yield:1", "close"]
iterator.close()
assert early.count("close") == 1
full: list[str] = []
assert list(values(full)) == [1, 2, 3]
assert full == ["open", "yield:1", "yield:2", "yield:3", "close"]
print("PASS: generator cleanup runs once on early close and exhaustion")
