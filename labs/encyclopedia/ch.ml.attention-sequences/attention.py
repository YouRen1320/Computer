"""Masked attention and an explicit Transformer block shape ledger."""

from __future__ import annotations

import math

import numpy as np


def stable_softmax(scores: np.ndarray, allowed: np.ndarray | None = None) -> np.ndarray:
    if allowed is not None:
        if allowed.shape != scores.shape or allowed.dtype != np.bool_:
            raise ValueError("allowed mask must be boolean and match scores")
        if np.any(~allowed.any(axis=-1)):
            raise ValueError("every query needs at least one visible key")
        scores = np.where(allowed, scores, -np.inf)
    shifted = scores - scores.max(axis=-1, keepdims=True)
    exponentials = np.exp(shifted)
    if allowed is not None:
        exponentials = np.where(allowed, exponentials, 0.0)
    return exponentials / exponentials.sum(axis=-1, keepdims=True)


def attention(
    q: np.ndarray,
    k: np.ndarray,
    v: np.ndarray,
    allowed: np.ndarray | None = None,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    if q.ndim != 2 or k.ndim != 2 or v.ndim != 2:
        raise ValueError("q, k and v must be rank-two")
    if q.shape[1] != k.shape[1] or k.shape[0] != v.shape[0]:
        raise ValueError("incompatible Q/K/V shapes")
    scores = q @ k.T / math.sqrt(q.shape[-1])
    weights = stable_softmax(scores, allowed)
    return scores, weights, weights @ v


def fixture() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    x = np.array(
        [[1.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 1.0], [1.0, 1.0, 1.0, 1.0]],
        dtype=np.float64,
    )
    w_v = np.array([[0.5, 0], [0.5, 0], [0, 0.5], [0, 0.5]], dtype=np.float64)
    return x.copy(), x.copy(), x @ w_v


def block_shape_trace(batch: int = 2, sequence: int = 3, model: int = 4, heads: int = 2) -> dict[str, tuple[int, ...]]:
    if model % heads != 0:
        raise ValueError("model dimension must be divisible by heads")
    head = model // heads
    return {
        "input": (batch, sequence, model),
        "qkv_per_head": (batch, heads, sequence, head),
        "scores": (batch, heads, sequence, sequence),
        "head_output": (batch, heads, sequence, head),
        "concatenated": (batch, sequence, model),
        "attention_projection": (batch, sequence, model),
        "first_residual": (batch, sequence, model),
        "ffn_hidden": (batch, sequence, model * 4),
        "ffn_output": (batch, sequence, model),
        "second_residual": (batch, sequence, model),
    }
