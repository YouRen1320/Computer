"""Verify success, failure chain and exactly-once cleanup."""

from __future__ import annotations

import json
import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from store import CorruptRepositoryData, TrackedResource, load  # noqa: E402


good = TrackedResource('[{"id": 1}]')
assert load(good) == [{"id": 1}]
assert (good.entered, good.exited) == (1, 1)
bad = TrackedResource("{")
try:
    load(bad)
except CorruptRepositoryData as error:
    assert isinstance(error.__cause__, json.JSONDecodeError)
else:
    raise AssertionError("corrupt fixture did not fail")
assert (bad.entered, bad.exited) == (1, 1)
print("PASS: cause is preserved and resources exit exactly once")
