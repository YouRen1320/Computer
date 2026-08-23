"""Private solution for the attention-axis exercise."""

import math

import numpy as np


def attention(q: np.ndarray, k: np.ndarray, v: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    scores = q @ k.T / math.sqrt(q.shape[-1])
    shifted = scores - scores.max(axis=-1, keepdims=True)
    exp_scores = np.exp(shifted)
    weights = exp_scores / exp_scores.sum(axis=-1, keepdims=True)
    return weights, weights @ v


def fixture() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    q = np.array([[1.0, 0.0], [0.0, 2.0], [1.0, 1.0]], dtype=np.float64)
    k = np.array([[2.0, 0.0], [0.0, 1.0], [1.0, -1.0]], dtype=np.float64)
    v = np.array([[1.0, 0.0], [0.0, 1.0], [1.0, 1.0]], dtype=np.float64)
    return q, k, v
