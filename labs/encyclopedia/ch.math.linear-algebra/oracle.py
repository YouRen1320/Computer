import numpy as np


x = np.array([[2.0, 1.0, 0.0], [1.0, 3.0, 2.0]])
w = np.array([[1.0, 2.0], [0.5, -1.0], [3.0, 1.0]])
b = np.array([10.0, -2.0])

predicted_shapes = {
    "x": (2, 3),
    "w": (3, 2),
    "x_at_w": (2, 2),
    "bias": (2,),
    "result": (2, 2),
}
assert x.shape == predicted_shapes["x"]
assert w.shape == predicted_shapes["w"]
result = x @ w + b
assert result.shape == predicted_shapes["result"]
np.testing.assert_allclose(result, [[12.5, 1.0], [18.5, -1.0]])

# Fault 1: reversing operands fails before producing a value: (3,2) @ (2,3) is
# mathematically legal but yields (3,3), so a shape assertion catches semantic order.
wrong_order = w @ x
assert wrong_order.shape == (3, 3)
assert wrong_order.shape != predicted_shapes["result"]

# Fault 2: a (2,1) column plus a (2,) row is legal broadcasting but expands to (2,2).
column = np.array([[1.0], [2.0]])
row = np.array([10.0, 20.0])
unexpected = column + row
assert unexpected.shape == (2, 2)
np.testing.assert_array_equal(unexpected, [[11.0, 21.0], [12.0, 22.0]])

# Fault 3: incompatible trailing dimensions give the first trustworthy failure.
try:
    np.ones((2, 3)) + np.ones((4,))
except ValueError as exc:
    assert "broadcast" in str(exc)
else:
    raise AssertionError("incompatible broadcast unexpectedly succeeded")

# Axis meaning is checked by a labeled shape, not by total element count.
batch_time_feature = np.arange(24).reshape(2, 3, 4)
time_batch_feature = np.swapaxes(batch_time_feature, 0, 1)
assert time_batch_feature.shape == (3, 2, 4)
assert time_batch_feature[1, 0, 2] == batch_time_feature[0, 1, 2]

print("PASS linear-algebra lab: order, axis, broadcast and mismatch faults are observable")
