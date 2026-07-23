import numpy as np


def loss(point: np.ndarray) -> float:
    x, y = point
    residual = 2 * x + y - 5
    return float(residual**2 + 0.5 * (x - 1) ** 2)


def analytic_gradient(point: np.ndarray) -> np.ndarray:
    """TODO: derive both partial derivatives using the chain rule."""
    x, y = point
    residual = 2 * x + y - 5
    # Deliberate fault: the x component misses d(2x+y-5)/dx = 2.
    return np.array([2 * residual + (x - 1), 2 * residual])
