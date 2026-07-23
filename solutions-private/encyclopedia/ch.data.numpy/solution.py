import numpy as np


def mean_per_day(values: np.ndarray) -> np.ndarray:
    source = np.asarray(values, dtype=np.float64)
    if source.ndim != 2 or 0 in source.shape:
        raise ValueError("expected non-empty (technician, day) matrix")
    return np.nanmean(source, axis=0)
