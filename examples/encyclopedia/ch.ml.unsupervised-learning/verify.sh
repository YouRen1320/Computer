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


def kmeans_from_centroids(
    values: np.ndarray,
    centroids: np.ndarray,
    *,
    max_iter: int = 100,
) -> tuple[np.ndarray, np.ndarray, float]:
    centroids = centroids.astype(float).copy()
    for _ in range(max_iter):
        squared_distances = ((values[:, None, :] - centroids[None, :, :]) ** 2).sum(axis=2)
        labels = squared_distances.argmin(axis=1)
        updated = np.vstack([values[labels == cluster].mean(axis=0) for cluster in range(len(centroids))])
        if np.allclose(updated, centroids):
            centroids = updated
            break
        centroids = updated
    inertia = float(((values - centroids[labels]) ** 2).sum())
    return labels, centroids, inertia


points = np.array([[0.0, 0.0], [0.0, 2.0], [10.0, 10.0], [10.0, 12.0]])
labels, centroids, inertia = kmeans_from_centroids(points, points[[0, 2]])
np.testing.assert_array_equal(labels, [0, 0, 1, 1])
np.testing.assert_allclose(centroids, [[0.0, 1.0], [10.0, 11.0]])
assert inertia == pytest.approx(4.0)

# 所有变化都在 x 轴，一维 PCA 可无损重构；主方向符号不作固定断言。
line = np.array([[-2.0, 0.0], [-1.0, 0.0], [1.0, 0.0], [2.0, 0.0]])
mean = line.mean(axis=0)
centered = line - mean
_, singular_values, components = np.linalg.svd(centered, full_matrices=False)
first = components[:1]
projected = centered @ first.T
reconstructed = projected @ first + mean
np.testing.assert_allclose(reconstructed, line, atol=1e-12)
assert singular_values[0] ** 2 / np.sum(singular_values ** 2) == pytest.approx(1.0)
np.testing.assert_allclose(np.abs(first[0]), [1.0, 0.0], atol=1e-12)

assert np.__version__ == "2.5.0"
assert pd.__version__ == "3.0.5"
assert pytest.__version__ == "9.1.1"
print("PASS unsupervised example: four-point K-means and lossless one-dimensional PCA")
PY
