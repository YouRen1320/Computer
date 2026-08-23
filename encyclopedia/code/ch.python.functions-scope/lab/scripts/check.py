"""Exercise the complete function input/output and repeated-call table."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from order_stats import append_trace, count_active, summarize


cases = [
    ([], 0),
    ([{"id": "WO-001", "status": "CLOSED"}], 0),
    (
        [
            {"id": "WO-001", "status": "ASSIGNED"},
            {"id": "WO-002", "status": "CLOSED"},
            {"id": "WO-003", "status": "IN_PROGRESS"},
        ],
        2,
    ),
]
for orders, expected in cases:
    before = [dict(order) for order in orders]
    assert count_active(orders) == expected
    assert orders == before

first = append_trace("first")
second = append_trace("second")
assert first == ["first"]
assert second == ["second"]
assert first is not second

summary = summarize(cases[-1][0], include_trace=True)
assert summary == {"total": 3, "active": 2, "trace": ["read=3", "active=2"]}
print("PASS: explicit returns, keyword-only option and fresh repeated-call state")
