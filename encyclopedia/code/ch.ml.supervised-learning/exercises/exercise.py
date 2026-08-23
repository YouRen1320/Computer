"""Editable starter: repair task, holdout, threshold and regularization contracts."""

from __future__ import annotations

import numpy as np


def task_for_labels(labels: list[str]) -> str:
    del labels
    return "regression"


def fit_ridge(x: np.ndarray, y: np.ndarray, alpha: float) -> np.ndarray:
    del alpha
    design = np.column_stack([np.ones(len(x)), x])
    return np.linalg.solve(design.T @ design, design.T @ y)


def classify(probability: np.ndarray, *, threshold: float) -> np.ndarray:
    del threshold
    return (probability >= 0.5).astype(int)


def generalization_report(*, train_score: float, holdout_score: float,
                          baseline_score: float) -> dict[str, float]:
    del holdout_score, baseline_score
    return {"train_score": train_score}
