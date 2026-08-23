"""Check the worked example and an independent finite-difference oracle."""

from __future__ import annotations

import pathlib
import sys

import numpy as np


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from network import backward, forward, half_squared_loss, initial_parameters, numerical_gradients, sgd_step


assert sys.version_info[:2] == (3, 14)
assert np.__version__ == "2.5.1"

x = np.array([1.0, 2.0], dtype=np.float64)
target = np.array([0.4], dtype=np.float64)
parameters = initial_parameters()
prediction, cache = forward(x, parameters)
assert np.allclose(cache["z1"], [2.5, 0.5])
assert np.allclose(cache["hidden"], [2.5, 0.5])
assert np.allclose(prediction, [1.0])
assert np.isclose(half_squared_loss(prediction, target), 0.18)

gradients = backward(prediction, target, cache, parameters)
np.testing.assert_allclose(gradients.w2, [[1.5], [0.3]])
np.testing.assert_allclose(gradients.b2, [0.6])
np.testing.assert_allclose(gradients.w1, [[0.24, -0.12], [0.48, -0.24]])
np.testing.assert_allclose(gradients.b1, [0.24, -0.12])

numeric = numerical_gradients(x, target, parameters)
for analytic_value, numeric_value in zip(gradients.values(), numeric.values(), strict=True):
    np.testing.assert_allclose(analytic_value, numeric_value, rtol=1e-6, atol=1e-7)

updated = sgd_step(parameters, gradients, learning_rate=0.1)
np.testing.assert_allclose(updated.w2, [[0.25], [-0.23]])
np.testing.assert_allclose(updated.b2, [0.04])
np.testing.assert_allclose(updated.w1, [[0.476, -0.988], [0.952, 0.524]])
np.testing.assert_allclose(updated.b1, [-0.024, 0.512])
new_loss = half_squared_loss(forward(x, updated)[0], target)
assert new_loss < 0.18

# This second point includes a negative pre-activation, so ReLU's derivative matters.
boundary_x = np.array([1.0, 0.0], dtype=np.float64)
boundary_target = np.array([0.0], dtype=np.float64)
boundary_prediction, boundary_cache = forward(boundary_x, parameters)
boundary_analytic = backward(boundary_prediction, boundary_target, boundary_cache, parameters)
boundary_numeric = numerical_gradients(boundary_x, boundary_target, parameters)
for analytic_value, numeric_value in zip(boundary_analytic.values(), boundary_numeric.values(), strict=True):
    np.testing.assert_allclose(analytic_value, numeric_value, rtol=1e-6, atol=1e-7)

print("PASS: hand forward/backward, shape boundary, finite differences and SGD update")
