from decimal import Decimal, ROUND_HALF_UP


def labor_cost_cents(duration_minutes: int, rate_cents_per_hour: int) -> int:
    if duration_minutes < 0 or rate_cents_per_hour < 0:
        raise ValueError("duration and rate must be non-negative")
    exact = Decimal(duration_minutes) * Decimal(rate_cents_per_hour) / Decimal(60)
    return int(exact.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def discounted_total_cents(material_cents: int, labor_cents: int, discount: Decimal) -> int:
    if not Decimal("0") <= discount <= Decimal("1"):
        raise ValueError("discount must be between 0 and 1")
    total = Decimal(material_cents + labor_cents) * (Decimal("1") - discount)
    return int(total.quantize(Decimal("1"), rounding=ROUND_HALF_UP))
