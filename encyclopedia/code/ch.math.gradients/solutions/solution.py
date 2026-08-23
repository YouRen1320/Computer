import numpy as np


def loss(point: np.ndarray) -> float:
    x, y = point
    residual = 2 * x + y - 5
    return float(residual**2 + 0.5 * (x - 1) ** 2)


def analytic_gradient(point: np.ndarray) -> np.ndarray:
    x, y = point
    residual = 2 * x + y - 5
    return np.array([4 * residual + (x - 1), 2 * residual])
