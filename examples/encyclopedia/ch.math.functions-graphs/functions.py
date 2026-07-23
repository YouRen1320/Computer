import math


def linear(x: float, slope: float, intercept: float) -> float:
    return slope * x + intercept


def slope(p1: tuple[float, float], p2: tuple[float, float]) -> float:
    if p1[0] == p2[0]:
        raise ValueError("slope is undefined for a vertical line")
    return (p2[1] - p1[1]) / (p2[0] - p1[0])


def compound(principal: float, rate: float, periods: float) -> float:
    return principal * (1 + rate) ** periods


def periods_to_target(principal: float, target: float, rate: float) -> float:
    return math.log(target / principal) / math.log(1 + rate)
