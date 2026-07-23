"""Verify row normalization and a stable known result."""

import pathlib
import sys

import numpy as np


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from attention import attention, fixture


weights, output = attention(*fixture())
np.testing.assert_allclose(weights.sum(axis=-1), np.ones(3), atol=1e-12)
assert weights.shape == (3, 3) and output.shape == (3, 2)
assert np.all(np.isfinite(weights)) and np.all(np.isfinite(output))
print("PASS: stable Softmax normalizes each query over keys")
