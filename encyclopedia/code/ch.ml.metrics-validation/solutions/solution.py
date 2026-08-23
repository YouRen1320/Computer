from __future__ import annotations

import numpy as np


def classification_report(actual: np.ndarray, predicted: np.ndarray) -> dict[str, float | int]:
    if actual.shape != predicted.shape or actual.size == 0:
        raise ValueError("actual and predicted must be non-empty equal shapes")
    tp = int(np.sum((actual == 1) & (predicted == 1)))
    fp = int(np.sum((actual == 0) & (predicted == 1)))
    fn = int(np.sum((actual == 1) & (predicted == 0)))
    return {
        "accuracy": float(np.mean(actual == predicted)),
        "recall": tp / (tp + fn) if tp + fn else 0.0,
        "precision": tp / (tp + fp) if tp + fp else 0.0,
    }


def group_holdout(groups: np.ndarray, validation_group: str) -> tuple[np.ndarray, np.ndarray]:
    validation = np.flatnonzero(groups == validation_group)
    train = np.flatnonzero(groups != validation_group)
    return train, validation


def decision_report(fold_scores: list[float], *, baseline: str,
                    predeclared_gate: str) -> dict[str, object]:
    if not fold_scores:
        raise ValueError("at least one fold score is required")
    return {"score": float(np.mean(fold_scores)), "baseline": baseline,
            "predeclared_gate": predeclared_gate}
