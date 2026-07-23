"""Verify collection choice, stable view and input ownership."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from group_orders import group_orders, stable_view


orders = [
    {"id": "WO-001", "technician_id": 7, "status": "ASSIGNED"},
    {"id": "WO-002", "technician_id": None, "status": "CREATED"},
    {"id": "WO-003", "technician_id": 7, "status": "IN_PROGRESS"},
    {"id": "WO-004", "technician_id": 7, "status": "ASSIGNED"},
    {"id": "WO-005", "technician_id": 8, "status": "RESOLVED"},
]
before = [dict(order) for order in orders]
grouped = group_orders(orders)
assert orders == before
assert grouped[7]["order_ids"] == ["WO-001", "WO-003", "WO-004"]
assert grouped[7]["statuses"] == {"ASSIGNED", "IN_PROGRESS"}
assert grouped[7]["count"] == 3
assert stable_view(grouped) == {
    "7": {
        "order_ids": ["WO-001", "WO-003", "WO-004"],
        "statuses": ["ASSIGNED", "IN_PROGRESS"],
        "count": 3,
    },
    "8": {"order_ids": ["WO-005"], "statuses": ["RESOLVED"], "count": 1},
}
print("PASS: dict grouping, ordered lists, unique sets and stable output")
