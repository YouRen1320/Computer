"""Expected-red check for the attention Softmax axis."""

import pathlib
import sys

import numpy as np


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from attention import attention, fixture


weights, _ = attention(*fixture())
np.testing.assert_allclose(
    weights.sum(axis=-1),
    np.ones(weights.shape[0]),
    atol=1e-12,
    err_msg="EXPECTED RED: each query must normalize over the key axis",
)
print("PASS: every query has a normalized key distribution")
