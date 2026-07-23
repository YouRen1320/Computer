from __future__ import annotations

from collections.abc import Sequence

import numpy as np


def describe_durations(values: Sequence[float]) -> dict[str, float]:
    durations = np.asarray(values, dtype=np.float64)
    if durations.ndim != 1 or durations.size == 0:
        raise ValueError("durations must be a non-empty 1-D sample")
    if not np.isfinite(durations).all() or (durations < 0).any():
        raise ValueError("durations must be finite and non-negative")
    return {
        "mean": float(np.mean(durations)),
        "median": float(np.median(durations)),
        "q25": float(np.quantile(durations, 0.25)),
        "q75": float(np.quantile(durations, 0.75)),
        "population_variance": float(np.var(durations, ddof=0)),
        "sample_variance": float(np.var(durations, ddof=1)) if durations.size > 1 else float("nan"),
    }


def conditional_probability(event: Sequence[bool], condition: Sequence[bool]) -> float:
    event_array = np.asarray(event, dtype=bool)
    condition_array = np.asarray(condition, dtype=bool)
    if event_array.shape != condition_array.shape or event_array.ndim != 1:
        raise ValueError("event and condition must be equal-length 1-D arrays")
    denominator = int(np.count_nonzero(condition_array))
    if denominator == 0:
        raise ValueError("conditional probability is undefined for an empty condition")
    numerator = int(np.count_nonzero(event_array & condition_array))
    return numerator / denominator


def discrete_moments(values: Sequence[float], probabilities: Sequence[float]) -> tuple[float, float]:
    x = np.asarray(values, dtype=np.float64)
    p = np.asarray(probabilities, dtype=np.float64)
    if x.ndim != 1 or x.shape != p.shape or x.size == 0:
        raise ValueError("values and probabilities must be matching non-empty vectors")
    if (p < 0).any() or not np.isclose(p.sum(), 1.0):
        raise ValueError("probabilities must be non-negative and sum to one")
    expectation = float(np.sum(x * p))
    variance = float(np.sum((x - expectation) ** 2 * p))
    return expectation, variance
