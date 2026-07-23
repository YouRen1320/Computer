from decimal import Decimal


def discounted_total(material_cents: int, duration_minutes: int, rate_cents_per_hour: int, discount: str) -> Decimal:
    # 练习缺口：分钟被错误地乘以 60，单位换算方向反了。
    hours = Decimal(duration_minutes) * Decimal(60)
    return (Decimal(material_cents) + hours * Decimal(rate_cents_per_hour)) * (Decimal("1") - Decimal(discount))
