"""Expected-red oracle for mutable default state."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from trace_log import append_trace


first = append_trace("created")
second = append_trace("assigned")
assert first == ["created"], f"EXPECTED RED: first call was polluted: {first!r}"
assert second == ["assigned"], f"EXPECTED RED: second call reused state: {second!r}"
assert first is not second, "EXPECTED RED: omitted calls must not share one list"
print("PASS: omitted trace calls own independent lists")
