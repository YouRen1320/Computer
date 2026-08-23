from decimal import Decimal

from calculator import discounted_total_cents, labor_cost_cents


assert labor_cost_cents(90, 8000) == 12000
assert labor_cost_cents(0, 8000) == 0
assert discounted_total_cents(20000, 12000, Decimal("0.10")) == 28800

try:
    labor_cost_cents(-1, 8000)
except ValueError:
    pass
else:
    raise AssertionError("negative duration must be rejected")

print("algebra and units example: PASS")
