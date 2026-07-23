"""Validate private cleanup and propagation."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from solution import Resource  # noqa: E402


resource = Resource()
try:
    with resource:
        raise RuntimeError("root cause")
except RuntimeError as error:
    assert str(error) == "root cause"
else:
    raise AssertionError("exception was suppressed")
assert resource.closed == 1
print("PASS: private context-manager solution")
