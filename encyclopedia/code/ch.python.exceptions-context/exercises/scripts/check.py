"""Stable expected-red checker for accidental suppression."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from exercise import Resource  # noqa: E402


resource = Resource()
propagated = False
try:
    with resource:
        raise RuntimeError("root cause")
except RuntimeError:
    propagated = True
assert propagated, "EXPECTED RED: __exit__ suppressed RuntimeError"
assert resource.closed == 1
print("PASS: exception propagates and cleanup runs once")
