import numpy as np

from solution import device_scores


x = np.array([[2.0, 1.0, 0.0], [1.0, 3.0, 2.0]])
w = np.array([[1.0, 2.0], [0.5, -1.0], [3.0, 1.0]])
b = np.array([10.0, -2.0])
np.testing.assert_allclose(device_scores(x, w, b), [[12.5, 1.0], [18.5, -1.0]])
try:
    device_scores(np.ones((2, 4)), w, b)
except ValueError:
    pass
else:
    raise AssertionError("invalid shape accepted")
print("PASS private linear-algebra solution")
