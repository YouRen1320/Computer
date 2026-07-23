"""Validate hand values, masks, shape trace and explicit failure behavior."""

import pathlib
import sys

import numpy as np


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from attention import attention, block_shape_trace, fixture


q, k, v = fixture()
scores, weights, output = attention(q, k, v)
np.testing.assert_allclose(scores, [[1, 0, 1], [0, 1, 1], [1, 1, 2]])
np.testing.assert_allclose(weights.sum(axis=-1), 1.0)
np.testing.assert_allclose(output[2], [0.7880584424, 0.7880584424], rtol=1e-9)

causal = np.tril(np.ones((3, 3), dtype=bool))
_, causal_weights, causal_output = attention(q, k, v, causal)
assert causal_weights.shape == (3, 3) and causal_output.shape == (3, 2)
assert np.all(causal_weights[~causal] == 0.0)
np.testing.assert_allclose(causal_weights.sum(axis=-1), np.ones(3))
np.testing.assert_allclose(causal_weights[0], [1.0, 0.0, 0.0])

trace = block_shape_trace()
assert trace["input"] == trace["attention_projection"] == trace["first_residual"]
assert trace["input"] == trace["ffn_output"] == trace["second_residual"]
assert trace["scores"] == (2, 2, 3, 3)

try:
    attention(q, k, v, np.zeros((3, 3), dtype=bool))
except ValueError as error:
    assert "visible key" in str(error)
else:
    raise AssertionError("an all-masked query must not silently produce NaN")

try:
    block_shape_trace(model=5, heads=2)
except ValueError as error:
    assert "divisible" in str(error)
else:
    raise AssertionError("invalid head split must be rejected")

print("PASS: hand attention, causal mask, all-masked boundary and block shape ledger")
