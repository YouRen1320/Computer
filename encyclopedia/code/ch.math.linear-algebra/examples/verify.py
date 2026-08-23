import platform

import numpy as np

from linear_features import hand_matmul, linear_scores

x_list = [[2.0, 1.0, 0.0], [1.0, 3.0, 2.0]]
w_list = [[1.0, 2.0], [0.5, -1.0], [3.0, 1.0]]
bias = np.array([10.0, -2.0])

# Hand oracle: row 0 is [2*1+1*0.5+0*3, 2*2+1*(-1)+0*1] = [2.5, 3].
hand = hand_matmul(x_list, w_list)
assert hand == [[2.5, 3.0], [8.5, 1.0]]
scores = linear_scores(x_list, w_list, bias)
assert scores.shape == (2, 2)
np.testing.assert_allclose(scores, [[12.5, 1.0], [18.5, -1.0]])

dot = np.array([2.0, 3.0]) @ np.array([4.0, 5.0])
assert float(dot) == 23.0

tensor = np.arange(24).reshape(2, 3, 4)
assert tensor.ndim == 3 and tensor.shape == (2, 3, 4)
swapped = np.swapaxes(tensor, 0, 1)
assert swapped.shape == (3, 2, 4)

for bad in (
    (np.ones((2, 4)), np.ones((3, 2)), np.ones(2)),
    (np.ones((2, 3)), np.ones((3, 2)), np.ones(3)),
):
    try:
        linear_scores(*bad)
    except ValueError:
        continue
    raise AssertionError("invalid shape contract was accepted")

print(f"PASS linear algebra example: Python {platform.python_version()}, NumPy {np.__version__}")
