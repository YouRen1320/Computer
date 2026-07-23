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


def standardize(values: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    mean = values.mean(axis=0)
    scale = values.std(axis=0, ddof=0)
    assert np.all(scale > 0)
    return (values - mean) / scale, mean, scale


def run_kmeans(
    values: np.ndarray,
    initial: np.ndarray,
    *,
    max_iter: int = 200,
) -> tuple[np.ndarray, np.ndarray, float]:
    centroids = initial.astype(float).copy()
    for _ in range(max_iter):
        distances = ((values[:, None, :] - centroids[None, :, :]) ** 2).sum(axis=2)
        labels = distances.argmin(axis=1)
        if len(np.unique(labels)) != len(centroids):
            return labels, centroids, float("inf")
        updated = np.vstack([values[labels == index].mean(axis=0) for index in range(len(centroids))])
        if np.allclose(updated, centroids, atol=1e-12):
            centroids = updated
            break
        centroids = updated
    inertia = float(((values - centroids[labels]) ** 2).sum())
    return labels, centroids, inertia


def best_kmeans(values: np.ndarray, *, seed: int, n_init: int = 24) -> tuple[np.ndarray, np.ndarray, float]:
    rng = np.random.default_rng(seed)
    candidates = []
    for _ in range(n_init):
        indices = rng.choice(len(values), size=2, replace=False)
        candidates.append(run_kmeans(values, values[indices]))
    return min(candidates, key=lambda item: item[2])


def coassociation(labels: np.ndarray) -> np.ndarray:
    return labels[:, None] == labels[None, :]


devices = pd.DataFrame({
    "device_id": ["A1", "A2", "A3", "A4", "B1", "B2", "B3", "B4"],
    "cycles": [1000, 2000, 3000, 4000, 1100, 2100, 3100, 4100],
    "error_rate": [0.01, 0.02, 0.01, 0.02, 0.90, 0.88, 0.92, 0.89],
    "temperature_variance": [1.0, 1.2, 0.9, 1.1, 8.9, 8.6, 9.2, 8.8],
})
feature_columns = ["cycles", "error_rate", "temperature_variance"]
raw = devices[feature_columns].to_numpy(dtype=float)
scaled, means, scales = standardize(raw)
np.testing.assert_allclose(scaled.mean(axis=0), 0.0, atol=1e-12)
np.testing.assert_allclose(scaled.std(axis=0), 1.0, atol=1e-12)

raw_labels, _, raw_inertia = best_kmeans(raw, seed=10)
scaled_runs = [best_kmeans(scaled, seed=seed) for seed in (1, 7, 19, 43, 101)]
scaled_labels, scaled_centroids, scaled_inertia = scaled_runs[0]

hypothesis_partition = np.array([0, 0, 0, 0, 1, 1, 1, 1])
assert not np.array_equal(coassociation(raw_labels), coassociation(hypothesis_partition))
assert np.array_equal(coassociation(scaled_labels), coassociation(hypothesis_partition))
for labels, _, inertia in scaled_runs[1:]:
    assert np.array_equal(coassociation(labels), coassociation(scaled_labels))
    assert inertia == pytest.approx(scaled_inertia, abs=1e-10)
assert np.isfinite(raw_inertia)

# PCA 只在同一份已缩放特征上拟合；二维仍保留非零重构误差。
centered = scaled - scaled.mean(axis=0)
_, singular_values, components = np.linalg.svd(centered, full_matrices=False)
components_2d = components[:2]
projected = centered @ components_2d.T
reconstructed = projected @ components_2d
reconstruction_mse = float(np.mean((centered - reconstructed) ** 2))
explained_ratio = (singular_values ** 2) / np.sum(singular_values ** 2)
assert projected.shape == (8, 2)
assert 0.0 < reconstruction_mse < 0.02
assert 0.98 < float(explained_ratio[:2].sum()) < 1.0

interpretation = "待验证假设：缩放后出现两个稳定的设备特征分区；簇编号不是风险等级。"
assert interpretation.startswith("待验证假设")
assert "不是风险等级" in interpretation

# 工件足以对新数据复用相同空间，而不是按新批次重新拟合。
assert means.shape == scales.shape == (3,)
assert scaled_centroids.shape == (2, 3)
assert np.__version__ == "2.5.0"
assert pd.__version__ == "3.0.5"
assert pytest.__version__ == "9.1.1"
print("PASS unsupervised lab: scaling delta, seed stability, PCA reconstruction and hypothesis boundary")
PY
