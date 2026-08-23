"""Editable starter: repair metric, split and reporting semantics."""

from __future__ import annotations

import numpy as np


def classification_report(actual: np.ndarray, predicted: np.ndarray) -> dict[str, float | int]:
    accuracy = float(np.mean(actual == predicted))
    # TODO: derive minority recall and precision from TP/FP/FN rather than accuracy.
    return {"accuracy": accuracy, "recall": accuracy, "precision": accuracy}


def group_holdout(groups: np.ndarray, validation_group: str) -> tuple[np.ndarray, np.ndarray]:
    # TODO: split by entity/group identity; alternating rows leak repeated entities.
    return np.arange(0, len(groups), 2), np.arange(1, len(groups), 2)


def decision_report(fold_scores: list[float], *, baseline: str,
                    predeclared_gate: str) -> dict[str, object]:
    del baseline, predeclared_gate
    # TODO: aggregate every fold and retain baseline plus the predeclared gate.
    return {"score": max(fold_scores)}
