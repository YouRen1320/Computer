"""Small monitoring primitives with explicit unavailable-quality state."""

from __future__ import annotations

from collections import Counter
from collections.abc import Sequence

import numpy as np


def category_proportions(values: Sequence[str], categories: Sequence[str]) -> np.ndarray:
    if not values:
        raise ValueError("a distribution needs at least one observation")
    if len(set(categories)) != len(categories):
        raise ValueError("categories must be unique")
    counts = Counter(values)
    unknown = set(counts) - set(categories)
    if unknown:
        raise ValueError(f"unknown categories: {sorted(unknown)}")
    return np.array([counts[category] / len(values) for category in categories], dtype=np.float64)


def total_variation(reference: np.ndarray, current: np.ndarray) -> float:
    if reference.shape != current.shape or reference.ndim != 1:
        raise ValueError("probability vectors must be one-dimensional and have equal shapes")
    if not np.isclose(reference.sum(), 1.0) or not np.isclose(current.sum(), 1.0):
        raise ValueError("probability vectors must each sum to one")
    return float(0.5 * np.abs(reference - current).sum())


def quality_snapshot(
    predictions: Sequence[int],
    labels: Sequence[int] | None,
    groups: Sequence[str],
) -> dict[str, object]:
    if len(predictions) != len(groups):
        raise ValueError("each prediction needs one group")
    if labels is None:
        return {"status": "pending_labels", "label_coverage": 0.0, "sample_count": len(predictions)}
    if len(labels) != len(predictions):
        raise ValueError("each prediction needs one mature label")
    correct = [prediction == label for prediction, label in zip(predictions, labels, strict=True)]
    subgroup: dict[str, dict[str, float | int]] = {}
    for group in sorted(set(groups)):
        indices = [index for index, value in enumerate(groups) if value == group]
        subgroup[group] = {
            "count": len(indices),
            "accuracy": sum(correct[index] for index in indices) / len(indices),
        }
    return {
        "status": "available",
        "label_coverage": 1.0,
        "sample_count": len(predictions),
        "accuracy": sum(correct) / len(correct),
        "subgroups": subgroup,
    }
