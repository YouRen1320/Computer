"""A tiny two-layer network whose every value can be checked by hand."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from numpy.typing import NDArray


FloatArray = NDArray[np.float64]


@dataclass
class Parameters:
    w1: FloatArray
    b1: FloatArray
    w2: FloatArray
    b2: FloatArray

    def copy(self) -> "Parameters":
        return Parameters(*(value.copy() for value in self.values()))

    def values(self) -> tuple[FloatArray, FloatArray, FloatArray, FloatArray]:
        return self.w1, self.b1, self.w2, self.b2


def initial_parameters() -> Parameters:
    return Parameters(
        w1=np.array([[0.5, -1.0], [1.0, 0.5]], dtype=np.float64),
        b1=np.array([0.0, 0.5], dtype=np.float64),
        w2=np.array([[0.4], [-0.2]], dtype=np.float64),
        b2=np.array([0.1], dtype=np.float64),
    )


def forward(x: FloatArray, parameters: Parameters) -> tuple[FloatArray, dict[str, FloatArray]]:
    if x.shape != (2,):
        raise ValueError(f"x must have shape (2,), got {x.shape}")
    z1 = x @ parameters.w1 + parameters.b1
    hidden = np.maximum(z1, 0.0)
    prediction = hidden @ parameters.w2 + parameters.b2
    return prediction, {"x": x, "z1": z1, "hidden": hidden}


def half_squared_loss(prediction: FloatArray, target: FloatArray) -> float:
    if prediction.shape != (1,) or target.shape != (1,):
        raise ValueError("prediction and target must both have shape (1,)")
    return float(0.5 * np.square(prediction - target).sum())


def backward(
    prediction: FloatArray,
    target: FloatArray,
    cache: dict[str, FloatArray],
    parameters: Parameters,
) -> Parameters:
    d_prediction = prediction - target
    d_w2 = np.outer(cache["hidden"], d_prediction)
    d_b2 = d_prediction.copy()
    d_hidden = d_prediction @ parameters.w2.T
    d_z1 = d_hidden * (cache["z1"] > 0.0)
    d_w1 = np.outer(cache["x"], d_z1)
    d_b1 = d_z1.copy()
    return Parameters(d_w1, d_b1, d_w2, d_b2)


def numerical_gradients(
    x: FloatArray,
    target: FloatArray,
    parameters: Parameters,
    epsilon: float = 1e-6,
) -> Parameters:
    result = parameters.copy()
    for gradient in result.values():
        gradient.fill(0.0)

    for parameter, gradient in zip(parameters.values(), result.values(), strict=True):
        for index in np.ndindex(parameter.shape):
            original = float(parameter[index])
            parameter[index] = original + epsilon
            plus = half_squared_loss(forward(x, parameters)[0], target)
            parameter[index] = original - epsilon
            minus = half_squared_loss(forward(x, parameters)[0], target)
            parameter[index] = original
            gradient[index] = (plus - minus) / (2.0 * epsilon)
    return result


def sgd_step(parameters: Parameters, gradients: Parameters, learning_rate: float) -> Parameters:
    return Parameters(
        *(value - learning_rate * gradient for value, gradient in zip(
            parameters.values(), gradients.values(), strict=True
        ))
    )
