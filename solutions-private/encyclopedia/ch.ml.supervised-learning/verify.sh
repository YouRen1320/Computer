#!/usr/bin/env bash
set -euo pipefail

uv run --isolated \
  --with 'numpy==2.5.0' \
  --with 'pandas==3.0.5' \
  --with 'pytest==9.1.1' \
  python - <<'PY'
import numpy as np
import pandas as pd
import pytest


def fit_ridge(x: np.ndarray, y: np.ndarray, alpha: float) -> np.ndarray:
    design = np.column_stack([np.ones(len(x)), x])
    penalty = np.diag([0.0, 1.0])
    return np.linalg.solve(design.T @ design + alpha * penalty, design.T @ y)


def classify(probability: np.ndarray, *, threshold: float) -> np.ndarray:
    return (probability >= threshold).astype(int)


x_train = np.array([0.0, 1.0, 2.0, 3.0])
y_train = np.array([1.0, 3.0, 5.0, 7.0])  # 数量目标，适合回归。
x_holdout = np.array([4.0, 5.0])
y_holdout = np.array([9.0, 11.0])
params = fit_ridge(x_train, y_train, alpha=0.0)
predicted = params[0] + params[1] * x_holdout
baseline = np.full_like(y_holdout, y_train.mean())
report = {
    "holdout_mae": float(np.mean(np.abs(y_holdout - predicted))),
    "baseline_mae": float(np.mean(np.abs(y_holdout - baseline))),
}
assert report["holdout_mae"] < report["baseline_mae"]

stronger = fit_ridge(x_train, y_train, alpha=50.0)
assert abs(stronger[1]) < abs(params[1])
probabilities = np.array([0.2, 0.55, 0.8])
np.testing.assert_array_equal(classify(probabilities, threshold=0.7), [0, 0, 1])

assert np.__version__ == "2.5.0"
assert pd.__version__ == "3.0.5"
assert pytest.__version__ == "9.1.1"
print("PASS private supervised solution: task, holdout, threshold and regularization contracts fixed")
PY
