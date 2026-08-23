"""Verify reduction, shapes, gradient values and a controlled failure boundary."""

from __future__ import annotations

import pathlib
import sys

import numpy as np


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from network import fixture_parameters, forward, gradients, mean_half_squared_loss, numerical_gradients, update


assert sys.version_info[:2] == (3, 14)
assert np.__version__ == "2.5.1"

x = np.array([[1.0, 2.0], [1.0, 0.0]], dtype=np.float64)
target = np.array([[0.4], [0.0]], dtype=np.float64)
parameters = fixture_parameters()
analytic, ledger = gradients(x, target, parameters)
assert ledger == {
    "x": (2, 2), "z1": (2, 2), "hidden": (2, 2), "prediction": (2, 1),
    "d_w1": (2, 2), "d_b1": (2,), "d_w2": (2, 1), "d_b2": (1,),
}
numeric = numerical_gradients(x, target, parameters)
for name, value in analytic.named().items():
    np.testing.assert_allclose(value, numeric.named()[name], rtol=1e-6, atol=1e-7, err_msg=name)

before = mean_half_squared_loss(forward(x, parameters)[0], target)
after_parameters = update(parameters, analytic, learning_rate=0.05)
after = mean_half_squared_loss(forward(x, after_parameters)[0], target)
assert after < before

try:
    gradients(np.array([1.0, 2.0]), np.array([[0.4]]), parameters)
except ValueError as error:
    assert "(batch, 2)" in str(error)
else:
    raise AssertionError("rank-one x must be rejected instead of silently dropping the batch axis")

try:
    gradients(np.empty((0, 2)), np.empty((0, 1)), parameters)
except ValueError as error:
    assert "empty batches" in str(error)
else:
    raise AssertionError("empty mean loss must be rejected")

print("PASS: batch reduction, shape ledger, all finite differences and failure boundaries")
