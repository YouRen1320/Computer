import numpy as np


def device_scores(features: np.ndarray, weights: np.ndarray, bias: np.ndarray) -> np.ndarray:
    x = np.asarray(features, dtype=float)
    w = np.asarray(weights, dtype=float)
    b = np.asarray(bias, dtype=float)
    if x.ndim != 2 or w.ndim != 2 or b.ndim != 1:
        raise ValueError("expected 2-D, 2-D and 1-D inputs")
    if x.shape[1] != w.shape[0] or w.shape[1] != b.shape[0]:
        raise ValueError("shape contract violated")
    return x @ w + b
