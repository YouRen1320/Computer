from __future__ import annotations

import numpy as np


def task_for_labels(labels: list[str]) -> str:
    if not labels or not all(isinstance(value, str) for value in labels):
        raise ValueError("nominal labels must be non-empty strings")
    return "classification"


def fit_ridge(x: np.ndarray, y: np.ndarray, alpha: float) -> np.ndarray:
    if alpha < 0:
        raise ValueError("alpha must be non-negative")
    design = np.column_stack([np.ones(len(x)), x])
    penalty = np.diag([0.0, 1.0])
    return np.linalg.solve(design.T @ design + alpha * penalty, design.T @ y)


def classify(probability: np.ndarray, *, threshold: float) -> np.ndarray:
    if not 0 <= threshold <= 1:
        raise ValueError("threshold must be between zero and one")
    return (probability >= threshold).astype(int)


def generalization_report(*, train_score: float, holdout_score: float,
                          baseline_score: float) -> dict[str, float]:
    return {"train_score": train_score, "holdout_score": holdout_score,
            "baseline_score": baseline_score}
