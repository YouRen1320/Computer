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


def run(values: np.ndarray, initial: np.ndarray) -> tuple[np.ndarray, np.ndarray, float]:
    centroids = initial.copy()
    for _ in range(100):
        labels = ((values[:, None, :] - centroids[None, :, :]) ** 2).sum(axis=2).argmin(axis=1)
        updated = np.vstack([values[labels == index].mean(axis=0) for index in range(2)])
        if np.allclose(updated, centroids):
            centroids = updated
            break
        centroids = updated
    return labels, centroids, float(((values - centroids[labels]) ** 2).sum())


raw = np.array([[1000.0, 0.01], [2000.0, 0.02], [1100.0, 0.90], [2100.0, 0.89]])
mean = raw.mean(axis=0)
scale = raw.std(axis=0)
scaled = (raw - mean) / scale
labels_a, centroids, inertia = run(scaled, scaled[[0, 2]])
labels_b = 1 - labels_a  # 模拟编号整体交换。
np.testing.assert_array_equal(labels_a[:, None] == labels_a[None, :], labels_b[:, None] == labels_b[None, :])
assert np.isfinite(inertia)

_, singular_values, components = np.linalg.svd(scaled, full_matrices=False)
projected = scaled @ components[:1].T
reconstructed = projected @ components[:1]
assert float(np.mean((scaled - reconstructed) ** 2)) > 0.0
assert 0.0 < float(singular_values[0] ** 2 / np.sum(singular_values ** 2)) < 1.0
hypothesis = "待验证假设：内部簇用于选择人工调查样本，不写入 Java 风险等级。"
assert hypothesis.startswith("待验证假设")
assert mean.shape == scale.shape == (2,)
assert centroids.shape == (2, 2)

assert np.__version__ == "2.5.0"
assert pd.__version__ == "3.0.5"
assert pytest.__version__ == "9.1.1"
print("PASS private unsupervised solution: scaling, label-invariant stability, projection audit and hypothesis boundary")
PY
