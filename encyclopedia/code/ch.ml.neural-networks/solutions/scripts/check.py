"""Verify the private solution against a numerical oracle."""

import pathlib
import sys

import numpy as np


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from network import analytic_w1_gradient, numeric_w1_gradient


x = np.array([1.0, 0.0], dtype=np.float64)
target = np.array([0.0], dtype=np.float64)
np.testing.assert_allclose(
    analytic_w1_gradient(x, target),
    numeric_w1_gradient(x, target),
    rtol=1e-6,
    atol=1e-7,
)
print("PASS: ReLU derivative and finite-difference oracle agree")
