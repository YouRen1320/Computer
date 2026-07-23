import numpy as np

from starter import mean_per_day

values = np.array([[10.0, 20.0, 30.0], [20.0, 30.0, np.nan]])
actual = mean_per_day(values)
expected = np.array([15.0, 25.0, 30.0])
np.testing.assert_allclose(actual, expected)
print("PASS numpy public exercise")
