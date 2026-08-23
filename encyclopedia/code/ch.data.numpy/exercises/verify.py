import numpy as np

from starter import mean_per_day

values = np.array([[10.0, 20.0, 30.0], [20.0, 30.0, np.nan]])
actual = mean_per_day(values)
expected = np.array([15.0, 25.0, 30.0])
np.testing.assert_allclose(actual, expected)
for invalid in (np.array([1.0]), np.empty((0, 2)), np.empty((2, 0))):
    try:
        mean_per_day(invalid)
    except ValueError:
        continue
    raise AssertionError(f"invalid shape accepted: {invalid.shape}")
print("PASS numpy public exercise")
