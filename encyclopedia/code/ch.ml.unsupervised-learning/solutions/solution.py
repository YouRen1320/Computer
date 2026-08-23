from __future__ import annotations

import numpy as np


def standardize(values: np.ndarray) -> np.ndarray:
    scale = values.std(axis=0)
    if np.any(scale == 0):
        raise ValueError("constant feature cannot be standardized for distance")
    return (values - values.mean(axis=0)) / scale


def same_partition(left: np.ndarray, right: np.ndarray) -> bool:
    if left.shape != right.shape:
        return False
    return bool(np.array_equal(left[:, None] == left[None, :],
                               right[:, None] == right[None, :]))


def projection_report(values: np.ndarray) -> dict[str, float | str]:
    _, singular_values, components = np.linalg.svd(values, full_matrices=False)
    projected = values @ components[:1].T
    reconstructed = projected @ components[:1]
    return {
        "evidence": "one-component-svd-with-loss-audit",
        "explained_variance_ratio": float(singular_values[0] ** 2 / np.sum(singular_values ** 2)),
        "reconstruction_mse": float(np.mean((values - reconstructed) ** 2)),
    }


def interpretation_record(*, seed_runs: int, data_version: str | None) -> dict[str, object]:
    if seed_runs < 2 or not data_version:
        raise ValueError("multiple seeds and a data version are required")
    return {"claim": "待验证假设：内部簇只用于选择人工调查样本。",
            "seed_runs": seed_runs, "data_version": data_version}
