"""Reference nearest-rank percentile implementation."""

import math


def percentile(values: list[float], quantile: float) -> float:
    if not values:
        raise ValueError("values must not be empty")
    if not 0 < quantile <= 1:
        raise ValueError("quantile must be in (0, 1]")
    ordered = sorted(values)
    return ordered[math.ceil(quantile * len(ordered)) - 1]
