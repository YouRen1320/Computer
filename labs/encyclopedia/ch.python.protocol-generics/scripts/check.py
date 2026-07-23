"""Run one contract suite against both structural implementations."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from lab import JsonLikeRepository, MemoryRepository, assert_contract  # noqa: E402


for implementation in (MemoryRepository, JsonLikeRepository):
    assert_contract(implementation())
print("PASS: both implementations satisfy the same repository contract")
