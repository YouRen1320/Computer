"""Stable expected-red structural contract check."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from exercise import BrokenRepository, WorkOrder  # noqa: E402


repo = BrokenRepository()
try:
    repo.save(WorkOrder(1))  # type: ignore[attr-defined]
except AttributeError as error:
    raise SystemExit(f"EXPECTED RED: Protocol member drift: {error}") from error
assert repo.get(1) == WorkOrder(1)
print("PASS: repository exposes save/get")
