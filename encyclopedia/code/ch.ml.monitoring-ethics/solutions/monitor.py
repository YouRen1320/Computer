"""Private solution using fixed-bin total variation."""

from collections.abc import Sequence

import numpy as np


EDGES = np.array([-np.inf, 0.5, 1.5, np.inf], dtype=np.float64)


def proportions(values: Sequence[float]) -> np.ndarray:
    counts, _ = np.histogram(np.asarray(values, dtype=np.float64), bins=EDGES)
    if counts.sum() == 0:
        raise ValueError("empty windows cannot establish a distribution")
    return counts / counts.sum()


def input_drift_distance(reference: Sequence[float], current: Sequence[float]) -> float:
    return float(0.5 * np.abs(proportions(reference) - proportions(current)).sum())


def input_drift_alert(reference: Sequence[float], current: Sequence[float]) -> bool:
    return input_drift_distance(reference, current) >= 0.25
