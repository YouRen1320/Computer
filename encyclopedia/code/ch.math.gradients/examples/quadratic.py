from __future__ import annotations

from collections.abc import Callable

import numpy as np
from numpy.typing import NDArray


Vector = NDArray[np.float64]


def loss(point: Vector) -> float:
    """f(x,y)=(2x+y-5)^2 + 0.5(x-1)^2."""
    x, y = np.asarray(point, dtype=np.float64)
    residual = 2.0 * x + y - 5.0
    return float(residual**2 + 0.5 * (x - 1.0) ** 2)


def analytic_gradient(point: Vector) -> Vector:
    x, y = np.asarray(point, dtype=np.float64)
    residual = 2.0 * x + y - 5.0
    # Chain rule: d(residual^2)/dx = 2*residual*2; /dy = 2*residual*1.
    return np.array([4.0 * residual + (x - 1.0), 2.0 * residual])


def central_difference(
    function: Callable[[Vector], float], point: Vector, h: float = 1e-5
) -> Vector:
    if not np.isfinite(h) or h <= 0:
        raise ValueError("h must be a positive finite number")
    x = np.asarray(point, dtype=np.float64)
    gradient = np.empty_like(x)
    for index in range(x.size):
        step = np.zeros_like(x)
        step[index] = h
        gradient[index] = (function(x + step) - function(x - step)) / (2.0 * h)
    return gradient


def descend(start: Vector, learning_rate: float, steps: int) -> tuple[Vector, list[float]]:
    if learning_rate <= 0 or steps < 0:
        raise ValueError("learning_rate must be positive and steps non-negative")
    point = np.asarray(start, dtype=np.float64).copy()
    trajectory = [loss(point)]
    for _ in range(steps):
        point -= learning_rate * analytic_gradient(point)
        trajectory.append(loss(point))
    return point, trajectory
