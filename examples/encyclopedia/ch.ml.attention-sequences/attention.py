"""Transparent NumPy implementation of single-head scaled attention."""

from __future__ import annotations

import math

import numpy as np
from numpy.typing import NDArray


Array = NDArray[np.float64]


def stable_softmax(scores: Array) -> Array:
    if scores.ndim != 2:
        raise ValueError("scores must have shape (query, key)")
    shifted = scores - scores.max(axis=-1, keepdims=True)
    exponentials = np.exp(shifted)
    return exponentials / exponentials.sum(axis=-1, keepdims=True)


def scaled_dot_product_attention(q: Array, k: Array, v: Array) -> tuple[Array, Array, Array]:
    if q.ndim != 2 or k.ndim != 2 or v.ndim != 2:
        raise ValueError("q, k and v must all be rank-two")
    if q.shape[1] != k.shape[1]:
        raise ValueError("q and k feature dimensions must match")
    if k.shape[0] != v.shape[0]:
        raise ValueError("every key must have one value")
    scores = q @ k.T / math.sqrt(q.shape[1])
    weights = stable_softmax(scores)
    output = weights @ v
    return scores, weights, output


def three_token_fixture() -> tuple[Array, Array, Array]:
    x = np.array(
        [[1.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 1.0], [1.0, 1.0, 1.0, 1.0]],
        dtype=np.float64,
    )
    w_v = np.array(
        [[0.5, 0.0], [0.5, 0.0], [0.0, 0.5], [0.0, 0.5]],
        dtype=np.float64,
    )
    return x.copy(), x.copy(), x @ w_v
