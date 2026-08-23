import math


def repair_fee(hours: float) -> float:
    if hours < 0:
        raise ValueError("hours must be non-negative")
    if hours <= 2:
        return 100 * hours
    return 200 + 130 * (hours - 2)


def device_value(year: int) -> float:
    if year < 0:
        raise ValueError("year must be non-negative")
    return max(120_000 * 0.8**year, 20_000)


def first_year_at_most(target: float) -> int:
    continuous = math.log(target / 120_000) / math.log(0.8)
    return math.ceil(continuous)


def inclusive_sum(values: list[int]) -> int:
    return sum(values)
