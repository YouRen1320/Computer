"""Verify the private nested ownership solution."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from tag_order import with_tag


source = {"id": "WO-001", "tags": ["device"]}
original_tags = source["tags"]
derived = with_tag(source, "urgent")
assert source == {"id": "WO-001", "tags": ["device"]}
assert derived == {"id": "WO-001", "tags": ["device", "urgent"]}
assert derived is not source
assert derived["tags"] is not original_tags

without_tags = {"id": "WO-002"}
assert with_tag(without_tags, "new") == {"id": "WO-002", "tags": ["new"]}
assert without_tags == {"id": "WO-002"}
print("PASS: private nested-list ownership solution")
