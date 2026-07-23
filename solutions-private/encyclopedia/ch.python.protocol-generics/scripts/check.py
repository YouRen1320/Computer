"""Validate the private structural solution."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from solution import Repository, WorkOrder  # noqa: E402


repo = Repository()
repo.save(WorkOrder(1))
assert repo.get(1) == WorkOrder(1)
print("PASS: private Protocol member solution")
