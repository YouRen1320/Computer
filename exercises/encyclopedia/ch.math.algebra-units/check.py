from decimal import Decimal

from quote import discounted_total

actual = discounted_total(20000, 90, 8000, "0.10")
expected = Decimal("28800")
assert actual == expected, f"expected {expected} cents from 1.5 hours, got {actual}"
