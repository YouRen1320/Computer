"""Batch-aware NumPy network used to audit reduction and shape contracts."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from numpy.typing import NDArray


Array = NDArray[np.float64]


@dataclass
class Parameters:
    w1: Array
    b1: Array
    w2: Array
    b2: Array

    def named(self) -> dict[str, Array]:
        return {"w1": self.w1, "b1": self.b1, "w2": self.w2, "b2": self.b2}

    def copy(self) -> "Parameters":
        return Parameters(*(value.copy() for value in self.named().values()))


def fixture_parameters() -> Parameters:
    return Parameters(
        np.array([[0.5, -1.0], [1.0, 0.5]], dtype=np.float64),
        np.array([0.0, 0.5], dtype=np.float64),
        np.array([[0.4], [-0.2]], dtype=np.float64),
        np.array([0.1], dtype=np.float64),
    )


def validate_batch(x: Array, target: Array) -> None:
    if x.ndim != 2 or x.shape[1] != 2:
        raise ValueError(f"x must have shape (batch, 2), got {x.shape}")
    if target.shape != (x.shape[0], 1):
        raise ValueError(f"target must have shape ({x.shape[0]}, 1), got {target.shape}")
    if x.shape[0] == 0:
        raise ValueError("empty batches have no defined mean loss")


def forward(x: Array, parameters: Parameters) -> tuple[Array, dict[str, Array]]:
    z1 = x @ parameters.w1 + parameters.b1
    hidden = np.maximum(z1, 0.0)
    prediction = hidden @ parameters.w2 + parameters.b2
    return prediction, {"x": x, "z1": z1, "hidden": hidden}


def mean_half_squared_loss(prediction: Array, target: Array) -> float:
    return float(np.mean(0.5 * np.square(prediction - target)))


def gradients(x: Array, target: Array, parameters: Parameters) -> tuple[Parameters, dict[str, tuple[int, ...]]]:
    validate_batch(x, target)
    prediction, cache = forward(x, parameters)
    d_prediction = (prediction - target) / x.shape[0]
    d_w2 = cache["hidden"].T @ d_prediction
    d_b2 = d_prediction.sum(axis=0)
    d_hidden = d_prediction @ parameters.w2.T
    d_z1 = d_hidden * (cache["z1"] > 0.0)
    d_w1 = x.T @ d_z1
    d_b1 = d_z1.sum(axis=0)
    ledger = {
        "x": x.shape,
        "z1": cache["z1"].shape,
        "hidden": cache["hidden"].shape,
        "prediction": prediction.shape,
        "d_w1": d_w1.shape,
        "d_b1": d_b1.shape,
        "d_w2": d_w2.shape,
        "d_b2": d_b2.shape,
    }
    return Parameters(d_w1, d_b1, d_w2, d_b2), ledger


def numerical_gradients(x: Array, target: Array, parameters: Parameters, epsilon: float = 1e-6) -> Parameters:
    validate_batch(x, target)
    result = parameters.copy()
    for value in result.named().values():
        value.fill(0.0)
    for name, parameter in parameters.named().items():
        numeric = result.named()[name]
        for index in np.ndindex(parameter.shape):
            original = float(parameter[index])
            parameter[index] = original + epsilon
            plus = mean_half_squared_loss(forward(x, parameters)[0], target)
            parameter[index] = original - epsilon
            minus = mean_half_squared_loss(forward(x, parameters)[0], target)
            parameter[index] = original
            numeric[index] = (plus - minus) / (2.0 * epsilon)
    return result


def update(parameters: Parameters, gradient: Parameters, learning_rate: float) -> Parameters:
    return Parameters(*(
        value - learning_rate * gradient.named()[name]
        for name, value in parameters.named().items()
    ))
