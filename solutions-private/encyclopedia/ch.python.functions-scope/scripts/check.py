"""Verify independent defaults and explicit caller-owned state."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from trace_log import append_trace


first = append_trace("created")
second = append_trace("assigned")
assert first == ["created"]
assert second == ["assigned"]
assert first is not second

provided = ["triaged"]
returned = append_trace("accepted", provided)
assert returned is provided
assert provided == ["triaged", "accepted"]
print("PASS: private None-sentinel solution")
