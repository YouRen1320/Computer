import numpy as np

from solution import mean_per_day

values = np.array([[10.0, 20.0, 30.0], [20.0, 30.0, np.nan]])
np.testing.assert_allclose(mean_per_day(values), [15.0, 25.0, 30.0])
for invalid in (np.array([1.0]), np.empty((0, 2))):
    try:
        mean_per_day(invalid)
    except ValueError:
        continue
    raise AssertionError("invalid shape accepted")
print("PASS numpy private solution")
