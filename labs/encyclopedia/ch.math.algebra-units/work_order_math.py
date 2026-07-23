from decimal import Decimal


def quote(duration_minutes: int, rate_cents_per_hour: int, material_cents: int, discount: str) -> dict[str, Decimal]:
    hours = Decimal(duration_minutes) / Decimal(60)
    labor = hours * Decimal(rate_cents_per_hour)
    before_discount = labor + Decimal(material_cents)
    after_discount = before_discount * (Decimal("1") - Decimal(discount))
    return {
        "hours": hours,
        "labor_cents": labor,
        "before_discount_cents": before_discount,
        "after_discount_cents": after_discount,
    }


def inverse_hours(total_cents: Decimal, material_cents: int, rate_cents_per_hour: int, discount: str) -> Decimal:
    before_discount = total_cents / (Decimal("1") - Decimal(discount))
    return (before_discount - Decimal(material_cents)) / Decimal(rate_cents_per_hour)
