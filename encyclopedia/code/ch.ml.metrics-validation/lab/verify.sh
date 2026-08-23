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


def fit_line(x: np.ndarray, y: np.ndarray) -> np.ndarray:
    design = np.column_stack([np.ones(len(x)), x])
    return np.linalg.lstsq(design, y, rcond=None)[0]


def predict_line(params: np.ndarray, x: np.ndarray) -> np.ndarray:
    return params[0] + params[1] * x


def mae(actual: np.ndarray, predicted: np.ndarray) -> float:
    return float(np.mean(np.abs(actual - predicted)))


def confusion(actual: np.ndarray, predicted: np.ndarray) -> dict[str, int]:
    return {
        "tp": int(np.sum((actual == 1) & (predicted == 1))),
        "fp": int(np.sum((actual == 0) & (predicted == 1))),
        "fn": int(np.sum((actual == 1) & (predicted == 0))),
        "tn": int(np.sum((actual == 0) & (predicted == 0))),
    }


def safe_ratio(numerator: int, denominator: int) -> float:
    return float(numerator / denominator) if denominator else 0.0


# 三设备分组交叉验证；每个样本只产生一次折外预测。
regression = pd.DataFrame({
    "sample_id": [f"r-{index}" for index in range(12)],
    "device_id": ["A"] * 4 + ["B"] * 4 + ["C"] * 4,
    "load": [0.0, 1.0, 2.0, 3.0, 0.5, 1.5, 2.5, 3.5, 1.0, 2.0, 3.0, 4.0],
    "minutes": [1.0, 3.2, 4.8, 7.1, 2.1, 3.9, 6.2, 7.8, 3.2, 4.9, 7.2, 8.9],
})
oof = np.full(len(regression), np.nan)
baseline_oof = np.full(len(regression), np.nan)
fold_rows = []
for fold, validation_group in enumerate(sorted(regression["device_id"].unique())):
    validation_mask = regression["device_id"].eq(validation_group).to_numpy()
    train_mask = ~validation_mask
    train_groups = set(regression.loc[train_mask, "device_id"])
    validation_groups = set(regression.loc[validation_mask, "device_id"])
    assert train_groups.isdisjoint(validation_groups)
    params = fit_line(
        regression.loc[train_mask, "load"].to_numpy(dtype=float),
        regression.loc[train_mask, "minutes"].to_numpy(dtype=float),
    )
    oof[validation_mask] = predict_line(params, regression.loc[validation_mask, "load"].to_numpy(dtype=float))
    baseline_oof[validation_mask] = regression.loc[train_mask, "minutes"].mean()
    fold_rows.append({
        "fold": fold,
        "validation_group": validation_group,
        "validation_count": int(validation_mask.sum()),
        "mae": mae(regression.loc[validation_mask, "minutes"].to_numpy(dtype=float), oof[validation_mask]),
    })
assert not np.isnan(oof).any()
assert sum(row["validation_count"] for row in fold_rows) == len(regression)
actual_minutes = regression["minutes"].to_numpy(dtype=float)
model_mae = mae(actual_minutes, oof)
baseline_mae = mae(actual_minutes, baseline_oof)
assert model_mae < baseline_mae * 0.25  # 预先声明的基线门槛。

# 在保存概率上复算三阈值矩阵与业务成本。
classification = pd.DataFrame({
    "sample_id": [f"c-{index}" for index in range(12)],
    "device_id": ["A", "A", "B", "B", "C", "C", "D", "D", "E", "E", "F", "F"],
    "site": ["N", "N", "N", "S", "S", "S", "N", "N", "S", "S", "N", "S"],
    "category": ["pump", "pump", "fan", "fan", "pump", "fan", "pump", "fan", "pump", "fan", "pump", "fan"],
    "priority": ["high", "low", "high", "low", "high", "low", "high", "low", "high", "low", "high", "low"],
    "actual": [1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0],
    "probability": [0.90, 0.80, 0.60, 0.40, 0.70, 0.55, 0.30, 0.10, 0.75, 0.20, 0.45, 0.05],
})
threshold_rows = []
actual = classification["actual"].to_numpy(dtype=int)
probability = classification["probability"].to_numpy(dtype=float)
for threshold in (0.3, 0.5, 0.7):
    predicted = (probability >= threshold).astype(int)
    counts = confusion(actual, predicted)
    threshold_rows.append({
        "threshold": threshold,
        **counts,
        "precision": safe_ratio(counts["tp"], counts["tp"] + counts["fp"]),
        "recall": safe_ratio(counts["tp"], counts["tp"] + counts["fn"]),
        "alerts": int(predicted.sum()),
        "cost": 5 * counts["fn"] + counts["fp"],
    })
threshold_matrix = pd.DataFrame(threshold_rows)
assert threshold_matrix["cost"].tolist() == [3, 12, 16]
selected = threshold_matrix.loc[threshold_matrix["cost"].idxmin()]
assert selected["threshold"] == pytest.approx(0.3)
assert selected["recall"] == pytest.approx(1.0)
majority_baseline_cost = 5 * int(actual.sum())
assert int(selected["cost"]) < majority_baseline_cost

# 按设备而不是行 bootstrap 回归折外绝对误差。
absolute_errors = np.abs(actual_minutes - oof)
device_values = regression["device_id"].unique()
rng = np.random.default_rng(20260724)
bootstrap_mae = []
for _ in range(500):
    sampled_groups = rng.choice(device_values, size=len(device_values), replace=True)
    sampled_errors = np.concatenate([
        absolute_errors[regression["device_id"].eq(group).to_numpy()]
        for group in sampled_groups
    ])
    bootstrap_mae.append(float(sampled_errors.mean()))
lower, upper = np.quantile(bootstrap_mae, [0.025, 0.975])
assert lower <= model_mae <= upper
assert upper - lower > 0.0

# 三种预先声明的误差切片，全部保留支持数和混淆计数。
slice_rows = []
selected_prediction = (probability >= float(selected["threshold"])).astype(int)
for column in ("site", "category", "priority"):
    for value, indices in classification.groupby(column, sort=True).groups.items():
        index_array = np.asarray(list(indices), dtype=int)
        counts = confusion(actual[index_array], selected_prediction[index_array])
        slice_rows.append({"dimension": column, "value": value, "support": len(index_array), **counts})
slices = pd.DataFrame(slice_rows)
assert set(slices["dimension"]) == {"site", "category", "priority"}
assert len(slices) == 6
assert int(slices["support"].sum()) == len(classification) * 3

assert np.__version__ == "2.5.0"
assert pd.__version__ == "3.0.5"
assert pytest.__version__ == "9.1.1"
print("PASS metrics lab: grouped CV, baseline gate, threshold cost, group bootstrap and three slice dimensions")
PY
