"""Intentionally wrong backward pass for the public exercise."""

import numpy as np


W1 = np.array([[0.5, -1.0], [1.0, 0.5]], dtype=np.float64)
B1 = np.array([0.0, 0.5], dtype=np.float64)
W2 = np.array([[0.4], [-0.2]], dtype=np.float64)
B2 = np.array([0.1], dtype=np.float64)


def loss(x: np.ndarray, target: np.ndarray) -> float:
    hidden = np.maximum(x @ W1 + B1, 0.0)
    prediction = hidden @ W2 + B2
    return float(0.5 * np.square(prediction - target).sum())


def analytic_w1_gradient(x: np.ndarray, target: np.ndarray) -> np.ndarray:
    z1 = x @ W1 + B1
    hidden = np.maximum(z1, 0.0)
    prediction = hidden @ W2 + B2
    d_hidden = (prediction - target) @ W2.T
    d_z1 = d_hidden  # Intentional defect: ReLU'(z1) is missing.
    return np.outer(x, d_z1)


def numeric_w1_gradient(x: np.ndarray, target: np.ndarray, epsilon: float = 1e-6) -> np.ndarray:
    result = np.zeros_like(W1)
    for index in np.ndindex(W1.shape):
        original = float(W1[index])
        W1[index] = original + epsilon
        plus = loss(x, target)
        W1[index] = original - epsilon
        minus = loss(x, target)
        W1[index] = original
        result[index] = (plus - minus) / (2.0 * epsilon)
    return result
