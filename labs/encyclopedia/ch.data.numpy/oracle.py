import numpy as np

matrix = np.array([[10.0, 20.0, 30.0], [20.0, 30.0, 40.0]])

wrong_axis = matrix.mean(axis=1)
assert wrong_axis.shape == (2,)
correct_axis = matrix.mean(axis=0)
assert correct_axis.shape == (3,)
np.testing.assert_allclose(correct_axis, [15.0, 25.0, 35.0])

column = np.array([[1.0], [2.0]])
row = np.array([10.0, 20.0])
silent_outer = column + row
assert silent_outer.shape == (2, 2)
paired = column[:, 0] + row
np.testing.assert_array_equal(paired, [11.0, 22.0])

with np.errstate(over="ignore"):
    overflowed = np.array([120], dtype=np.int8) + np.array([20], dtype=np.int8)
assert int(overflowed[0]) == -116
safe = np.array([120], dtype=np.int64) + np.array([20], dtype=np.int64)
assert int(safe[0]) == 140

source = np.array([1, 2, 3, 4], dtype=np.int64)
view = source[1:3]
assert np.shares_memory(source, view)
view[0] = 99
assert source[1] == 99
snapshot = source[1:3].copy()
snapshot[0] = -1
assert source[1] == 99

try:
    _ = np.empty((2, 3)) + np.empty((2,))
except ValueError:
    pass
else:
    raise AssertionError("incompatible trailing dimensions must fail")

print("PASS numpy lab: axis, silent broadcast, overflow and view faults reproduced")
