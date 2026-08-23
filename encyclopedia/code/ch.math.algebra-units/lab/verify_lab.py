from decimal import Decimal

from work_order_math import inverse_hours, quote

result = quote(105, 9600, 12500, "0.08")
assert result["hours"] == Decimal("1.75")
assert result["labor_cents"] == Decimal("16800.00")
assert result["after_discount_cents"] == Decimal("26956.0000")
assert inverse_hours(result["after_discount_cents"], 12500, 9600, "0.08") == Decimal("1.75")
assert Decimal("25000") < result["after_discount_cents"] < Decimal("30000")
print("dimension, estimate and inverse-substitution: PASS")
