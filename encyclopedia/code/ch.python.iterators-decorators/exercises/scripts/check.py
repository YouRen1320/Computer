"""Stable expected-red metadata checker."""

from __future__ import annotations

import inspect
import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from exercise import close_order  # noqa: E402


assert close_order(1) == "closed:1"
assert close_order.__name__ == "close_order", "EXPECTED RED: decorator lost __name__"
assert close_order.__doc__ == "Close one order."
assert "order_id" in inspect.signature(close_order).parameters
assert hasattr(close_order, "__wrapped__")
print("PASS: decorator preserves function metadata")
