"""Compare every attention intermediate with the hand-derived oracle."""

import pathlib
import sys

import numpy as np


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from attention import scaled_dot_product_attention, three_token_fixture


assert sys.version_info[:2] == (3, 14)
assert np.__version__ == "2.5.1"
q, k, v = three_token_fixture()
assert q.shape == (3, 4) and k.shape == (3, 4) and v.shape == (3, 2)
scores, weights, output = scaled_dot_product_attention(q, k, v)
np.testing.assert_allclose(scores, [[1, 0, 1], [0, 1, 1], [1, 1, 2]])
expected_weights = np.array(
    [
        [0.4223187983, 0.1553624035, 0.4223187983],
        [0.1553624035, 0.4223187983, 0.4223187983],
        [0.2119415576, 0.2119415576, 0.5761168848],
    ]
)
np.testing.assert_allclose(weights, expected_weights, rtol=1e-9, atol=1e-9)
np.testing.assert_allclose(weights.sum(axis=-1), np.ones(3))
np.testing.assert_allclose(
    output,
    [[0.8446375966, 0.5776812017], [0.5776812017, 0.8446375966], [0.7880584424, 0.7880584424]],
    rtol=1e-9,
    atol=1e-9,
)
assert output.shape == (3, 2)
print("PASS: Q/K/V shapes, scaled scores, row softmax and weighted output")
