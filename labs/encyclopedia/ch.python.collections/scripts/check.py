"""Run collection case tables, identity checks and expected failures."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from collection_lab import index_statuses, unique_in_first_seen_order, with_tag


assert unique_in_first_seen_order([]) == []
assert unique_in_first_seen_order(["B", "A", "B", "C", "A"]) == ["B", "A", "C"]

orders = [
    {"tenant_id": "t1", "id": "WO-001", "status": "CREATED"},
    {"tenant_id": "t2", "id": "WO-001", "status": "ASSIGNED"},
]
assert index_statuses(orders) == {
    ("t1", "WO-001"): "CREATED",
    ("t2", "WO-001"): "ASSIGNED",
}

try:
    index_statuses([orders[0], dict(orders[0])])
except ValueError as error:
    assert "duplicate order key" in str(error)
else:
    raise AssertionError("duplicate compound keys must fail")

source = {"id": "WO-001", "tags": ["device"]}
derived = with_tag(source, "urgent")
assert source == {"id": "WO-001", "tags": ["device"]}
assert derived == {"id": "WO-001", "tags": ["device", "urgent"]}
assert derived is not source
assert derived["tags"] is not source["tags"]

try:
    {(["t1", "WO-001"], "CREATED")}
except TypeError as error:
    assert "unhashable" in str(error)
else:
    raise AssertionError("a list inside a set member must be unhashable")

print("PASS: ordering, compound keys, duplicate failure and nested ownership")
