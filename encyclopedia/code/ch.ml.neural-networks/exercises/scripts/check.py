"""Expected-red oracle for the omitted activation derivative."""

import pathlib
import sys

import numpy as np


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from network import analytic_w1_gradient, numeric_w1_gradient


x = np.array([1.0, 0.0], dtype=np.float64)
target = np.array([0.0], dtype=np.float64)
analytic = analytic_w1_gradient(x, target)
numeric = numeric_w1_gradient(x, target)
np.testing.assert_allclose(
    analytic,
    numeric,
    rtol=1e-6,
    atol=1e-7,
    err_msg="EXPECTED RED: hidden backward omitted ReLU'(z1)",
)
print("PASS: hidden activation derivative is included")
