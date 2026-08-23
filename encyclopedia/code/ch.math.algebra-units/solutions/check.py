from decimal import Decimal

from quote import discounted_total

assert discounted_total(20000, 90, 8000, "0.10") == Decimal("28800.0")
assert discounted_total(0, 0, 8000, "0.10") == Decimal("0.0")
print("algebra and units private solution: PASS")
