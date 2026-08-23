"""Expected-red oracle for accidental nested mutation."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from tag_order import with_tag


source = {"id": "WO-001", "tags": ["device"]}
original_tags = source["tags"]
derived = with_tag(source, "urgent")
assert source == {"id": "WO-001", "tags": ["device"]}, (
    f"EXPECTED RED: input was mutated: {source!r}"
)
assert derived == {"id": "WO-001", "tags": ["device", "urgent"]}
assert derived["tags"] is not original_tags, "EXPECTED RED: nested list is shared"
print("PASS: derived tags do not mutate or alias the input")
