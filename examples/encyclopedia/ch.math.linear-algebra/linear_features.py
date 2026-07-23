from __future__ import annotations

import numpy as np
from numpy.typing import ArrayLike, NDArray


def linear_scores(
    features: ArrayLike,
    weights: ArrayLike,
    bias: ArrayLike,
) -> NDArray[np.float64]:
    """Apply one explicit batch-feature @ feature-output linear transform."""
    x = np.asarray(features, dtype=np.float64)
    w = np.asarray(weights, dtype=np.float64)
    b = np.asarray(bias, dtype=np.float64)
    if x.ndim != 2 or w.ndim != 2 or b.ndim != 1:
        raise ValueError("expected features 2-D, weights 2-D, bias 1-D")
    if x.shape[1] != w.shape[0]:
        raise ValueError(f"inner dimensions differ: {x.shape} @ {w.shape}")
    if w.shape[1] != b.shape[0]:
        raise ValueError(f"bias {b.shape} does not match output width {w.shape[1]}")
    return x @ w + b


def hand_matmul(left: list[list[float]], right: list[list[float]]) -> list[list[float]]:
    """Small readable oracle; intended for checking, not high-volume computation."""
    if not left or not right or not right[0]:
        raise ValueError("matrices must be non-empty")
    if any(len(row) != len(left[0]) for row in left):
        raise ValueError("left matrix is ragged")
    if any(len(row) != len(right[0]) for row in right):
        raise ValueError("right matrix is ragged")
    if len(left[0]) != len(right):
        raise ValueError("inner dimensions differ")
    return [
        [sum(left[i][k] * right[k][j] for k in range(len(right))) for j in range(len(right[0]))]
        for i in range(len(left))
    ]
