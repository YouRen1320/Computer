import numpy as np

from starter import device_scores


x = np.array([[2.0, 1.0, 0.0], [1.0, 3.0, 2.0]])
w = np.array([[1.0, 2.0], [0.5, -1.0], [3.0, 1.0]])
b = np.array([10.0, -2.0])
result = device_scores(x, w, b)
assert result.shape == (2, 2)
np.testing.assert_allclose(result, [[12.5, 1.0], [18.5, -1.0]])
