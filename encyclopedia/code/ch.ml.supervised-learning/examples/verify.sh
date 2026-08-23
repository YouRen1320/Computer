#!/usr/bin/env bash
set -euo pipefail

uv run --isolated \
  --with 'numpy==2.5.0' \
  --with 'pandas==3.0.5' \
  --with 'pytest==9.1.1' \
  python - <<'PY'
import math

import numpy as np
import pandas as pd
import pytest


frame = pd.DataFrame({"alarm_count": [1.0, 2.0, 3.0], "repair_minutes": [3.0, 5.0, 7.0]})
x = frame["alarm_count"].to_numpy()
y = frame["repair_minutes"].to_numpy()

# 一元最小二乘的手算 oracle。
x_mean = float(x.mean())
y_mean = float(y.mean())
slope = float(np.sum((x - x_mean) * (y - y_mean)) / np.sum((x - x_mean) ** 2))
intercept = y_mean - slope * x_mean
assert slope == pytest.approx(2.0)
assert intercept == pytest.approx(1.0)
assert intercept + slope * 4.0 == pytest.approx(9.0)

design = np.column_stack([np.ones(len(x)), x])
lstsq_params = np.linalg.lstsq(design, y, rcond=None)[0]
np.testing.assert_allclose(lstsq_params, [1.0, 2.0], atol=1e-12)
predictions = design @ lstsq_params
residuals = y - predictions
np.testing.assert_allclose(residuals, [0.0, 0.0, 0.0], atol=1e-12)

# sigmoid 与阈值可脱离训练过程手算。
scores = np.array([-math.log(3.0), 0.0, math.log(3.0)])
probabilities = 1.0 / (1.0 + np.exp(-scores))
np.testing.assert_allclose(probabilities, [0.25, 0.5, 0.75], atol=1e-12)
np.testing.assert_array_equal((probabilities >= 0.7).astype(int), [0, 0, 1])

assert np.__version__ == "2.5.0"
assert pd.__version__ == "3.0.5"
assert pytest.__version__ == "9.1.1"
print("PASS supervised example: hand OLS, residual, sigmoid and threshold oracles")
PY
