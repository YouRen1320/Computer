"""Run substitution and annotation relationship checks."""

from __future__ import annotations

import pathlib
import sys
from typing import get_type_hints


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from repository import MemoryRepository, WorkOrder, close_order  # noqa: E402


repo = MemoryRepository()
assert repo.get(1) is None
repo.save(WorkOrder(id=1, status="ASSIGNED"))
closed = close_order(repo, 1)
assert closed == WorkOrder(id=1, status="CLOSED")
assert repo.get(1) == closed
hints = get_type_hints(close_order)
assert hints["return"] is WorkOrder
print("PASS: structural MemoryRepository satisfies the runtime contract")
