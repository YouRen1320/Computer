from decimal import Decimal


def discounted_total(material_cents: int, duration_minutes: int, rate_cents_per_hour: int, discount: str) -> Decimal:
    hours = Decimal(duration_minutes) / Decimal(60)
    return (Decimal(material_cents) + hours * Decimal(rate_cents_per_hour)) * (Decimal("1") - Decimal(discount))
