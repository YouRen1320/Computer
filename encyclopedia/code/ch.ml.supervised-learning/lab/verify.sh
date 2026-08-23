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


def design_matrix(x: np.ndarray) -> np.ndarray:
    return np.column_stack([np.ones(len(x)), x.astype(float)])


def fit_ols(x: np.ndarray, y: np.ndarray) -> np.ndarray:
    return np.linalg.lstsq(design_matrix(x), y.astype(float), rcond=None)[0]


def fit_ridge(x: np.ndarray, y: np.ndarray, alpha: float) -> np.ndarray:
    design = design_matrix(x)
    penalty = np.diag([0.0, 1.0])  # 截距不惩罚。
    return np.linalg.solve(design.T @ design + alpha * penalty, design.T @ y)


def sigmoid(scores: np.ndarray) -> np.ndarray:
    positive = scores >= 0
    result = np.empty_like(scores, dtype=float)
    result[positive] = 1.0 / (1.0 + np.exp(-scores[positive]))
    exp_scores = np.exp(scores[~positive])
    result[~positive] = exp_scores / (1.0 + exp_scores)
    return result


def fit_logistic(x: np.ndarray, y: np.ndarray) -> np.ndarray:
    design = design_matrix(x)
    weights = np.zeros(2, dtype=float)
    for _ in range(4000):
        probabilities = sigmoid(design @ weights)
        gradient = design.T @ (probabilities - y) / len(y)
        gradient[1] += 0.01 * weights[1]
        weights -= 0.2 * gradient
    return weights


def mae(actual: np.ndarray, predicted: np.ndarray) -> float:
    return float(np.mean(np.abs(actual - predicted)))


# 回归：训练拟合与固定留出严格分离。
train_reg = pd.DataFrame({
    "sample_id": [f"train-r-{index}" for index in range(6)],
    "alarm_count": [0, 1, 2, 3, 4, 5],
    "repair_minutes": [10, 16, 19, 26, 29, 35],
})
holdout_reg = pd.DataFrame({
    "sample_id": ["holdout-r-6", "holdout-r-7", "holdout-r-8"],
    "alarm_count": [6, 7, 8],
    "repair_minutes": [40, 46, 49],
})
assert set(train_reg["sample_id"]).isdisjoint(holdout_reg["sample_id"])

x_train = train_reg["alarm_count"].to_numpy(dtype=float)
y_train = train_reg["repair_minutes"].to_numpy(dtype=float)
x_holdout = holdout_reg["alarm_count"].to_numpy(dtype=float)
y_holdout = holdout_reg["repair_minutes"].to_numpy(dtype=float)
ols = fit_ols(x_train, y_train)
holdout_prediction = design_matrix(x_holdout) @ ols
baseline_prediction = np.full_like(y_holdout, y_train.mean())
residuals = y_holdout - holdout_prediction
assert mae(y_holdout, holdout_prediction) < mae(y_holdout, baseline_prediction)
np.testing.assert_allclose(residuals, y_holdout - (ols[0] + ols[1] * x_holdout))
assert ols[0] == pytest.approx(10.285714285714, abs=1e-9)
assert ols[1] == pytest.approx(4.885714285714, abs=1e-9)

unregularized = fit_ridge(x_train, y_train, alpha=0.0)
stronger_penalty = fit_ridge(x_train, y_train, alpha=50.0)
assert abs(stronger_penalty[1]) < abs(unregularized[1])

# 分类：概率模型和阈值策略分别保存。
x_class_train = np.array([-3.0, -2.0, -1.0, 1.0, 2.0, 3.0])
y_class_train = np.array([0.0, 0.0, 0.0, 1.0, 1.0, 1.0])
x_class_holdout = np.array([-2.5, -0.5, 0.5, 2.5])
y_class_holdout = np.array([0, 0, 1, 1])
weights = fit_logistic(x_class_train, y_class_train)
probabilities = sigmoid(design_matrix(x_class_holdout) @ weights)
np.testing.assert_allclose(probabilities, sigmoid(weights[0] + weights[1] * x_class_holdout))
assert np.all(np.diff(probabilities) > 0)
predicted_at_half = (probabilities >= 0.5).astype(int)
baseline_class = np.zeros_like(y_class_holdout)
assert float(np.mean(predicted_at_half == y_class_holdout)) == 1.0
assert float(np.mean(baseline_class == y_class_holdout)) == 0.5

threshold_rows = []
for threshold in (0.3, 0.5, 0.7):
    predicted = (probabilities >= threshold).astype(int)
    threshold_rows.append({
        "threshold": threshold,
        "predicted_positive": int(predicted.sum()),
        "decisions": predicted.tolist(),
    })
threshold_evidence = pd.DataFrame(threshold_rows)
assert threshold_evidence["threshold"].tolist() == [0.3, 0.5, 0.7]
assert threshold_evidence.loc[1, "decisions"] == [0, 0, 1, 1]

evidence = holdout_reg.assign(prediction=holdout_prediction, residual=residuals)
np.testing.assert_allclose(evidence["repair_minutes"] - evidence["prediction"], evidence["residual"])
assert np.__version__ == "2.5.0"
assert pd.__version__ == "3.0.5"
assert pytest.__version__ == "9.1.1"
print("PASS supervised lab: held-out baselines, coefficients, residuals, shrinkage, probabilities and thresholds")
PY
