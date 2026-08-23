import platform

import numpy as np

from duration_matrix import normalize_durations

source = np.array(
    [
        [10.0, 20.0, 7.0, np.nan],
        [20.0, 30.0, 7.0, np.nan],
        [30.0, np.nan, 7.0, np.nan],
    ],
    dtype=np.float64,
)
before = source.copy()
result = normalize_durations(source)

np.testing.assert_array_equal(source, before)
assert result.values.shape == source.shape
assert result.day_mean.shape == (1, 4)
assert result.day_std.shape == (1, 4)
assert result.valid_count.shape == (1, 4)
np.testing.assert_array_equal(result.valid_count, [[3, 2, 3, 0]])
np.testing.assert_allclose(
    result.day_mean,
    [[20.0, 25.0, 7.0, np.nan]],
    equal_nan=True,
)
np.testing.assert_array_equal(result.zero_variance, [[False, False, True, False]])
np.testing.assert_allclose(result.values[:, 2], [0.0, 0.0, 0.0])
assert np.isnan(result.values[:, 3]).all()

for invalid in (np.array([1.0, 2.0]), np.empty((0, 3)), [[1.0, np.inf]]):
    try:
        normalize_durations(invalid)
    except ValueError:
        continue
    raise AssertionError(f"invalid matrix accepted: shape={np.asarray(invalid).shape}")

print(f"PASS numpy example: Python {platform.python_version()}, NumPy {np.__version__}")
