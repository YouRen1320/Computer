from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import numpy as np
from numpy.typing import NDArray


FloatArray = NDArray[np.float64]
IntArray = NDArray[np.int64]
BoolArray = NDArray[np.bool_]


@dataclass(frozen=True)
class NormalizedDurations:
    values: FloatArray
    day_mean: FloatArray
    day_std: FloatArray
    valid_count: IntArray
    zero_variance: BoolArray


def normalize_durations(values: Any) -> NormalizedDurations:
    source = np.asarray(values, dtype=np.float64)
    if source.ndim != 2:
        raise ValueError("durations must have shape (technician, day)")
    if source.shape[0] == 0 or source.shape[1] == 0:
        raise ValueError("both technician and day axes must be non-empty")
    if np.isinf(source).any():
        raise ValueError("durations must not contain infinity")

    valid = ~np.isnan(source)
    count = valid.sum(axis=0, keepdims=True, dtype=np.int64)
    total = np.nansum(source, axis=0, keepdims=True, dtype=np.float64)
    mean = np.divide(
        total,
        count,
        out=np.full((1, source.shape[1]), np.nan, dtype=np.float64),
        where=count > 0,
    )
    centered = source - mean
    square_total = np.nansum(centered * centered, axis=0, keepdims=True)
    variance = np.divide(
        square_total,
        count,
        out=np.full_like(mean, np.nan),
        where=count > 0,
    )
    std = np.sqrt(variance)
    zero_variance = (std == 0) & (count > 0)
    safe_std = np.where(zero_variance, 1.0, std)
    normalized = centered / safe_std

    return NormalizedDurations(
        values=normalized,
        day_mean=mean,
        day_std=std,
        valid_count=count,
        zero_variance=zero_variance,
    )
