"""Verify returns, parameter binding, callable values and input ownership."""

from __future__ import annotations

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from functions_scope import calculate_total, count_matching, is_urgent, with_hint


assert calculate_total(1999, 3) == 5997
assert calculate_total(unit_price_cents=1999, quantity=0) == 0

try:
    calculate_total(-1, 3)
except ValueError as error:
    assert "non-negative" in str(error)
else:
    raise AssertionError("negative prices must fail")

assert callable(is_urgent)
assert count_matching([1, 4, 5, 2], is_urgent) == 2

source = {"id": "WO-001", "status": "ASSIGNED"}
derived = with_hint(source, "REVIEW_SOON")
assert source == {"id": "WO-001", "status": "ASSIGNED"}
assert derived == {"id": "WO-001", "status": "ASSIGNED", "hint": "REVIEW_SOON"}
assert derived is not source
print("PASS: function contracts, returns and input ownership")
