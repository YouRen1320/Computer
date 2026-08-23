"""Deterministic monitoring drill, not a production observability platform."""

from __future__ import annotations

from collections.abc import Sequence

import numpy as np
import pandas as pd


def fixed_bin_proportions(values: Sequence[float], edges: Sequence[float]) -> np.ndarray:
    array = np.asarray(values, dtype=np.float64)
    boundary = np.asarray(edges, dtype=np.float64)
    if array.size == 0 or boundary.ndim != 1 or boundary.size < 2:
        raise ValueError("values and ordered bin edges must be non-empty")
    if np.any(np.diff(boundary) <= 0):
        raise ValueError("bin edges must be strictly increasing")
    counts, _ = np.histogram(array, bins=boundary)
    if counts.sum() != array.size:
        raise ValueError("bin edges must cover every value, including overflow")
    return counts.astype(np.float64) / counts.sum()


def total_variation(reference: np.ndarray, current: np.ndarray) -> float:
    if reference.shape != current.shape:
        raise ValueError("reference and current bins must match")
    return float(0.5 * np.abs(reference - current).sum())


def backfill_labels(predictions: pd.DataFrame, labels: pd.DataFrame) -> pd.DataFrame:
    required_prediction = {"prediction_id", "group", "prediction", "model_version"}
    required_label = {"prediction_id", "label"}
    if not required_prediction <= set(predictions.columns):
        raise ValueError("prediction contract is incomplete")
    if not required_label <= set(labels.columns):
        raise ValueError("label contract is incomplete")
    return predictions.merge(labels, on="prediction_id", how="left", validate="one_to_one")


def quality_report(records: pd.DataFrame, minimum_group_size: int = 2) -> dict[str, object]:
    if "label" not in records:
        raise ValueError("records need a label column, even when labels are pending")
    mature = records.loc[records["label"].notna()].copy()
    coverage = len(mature) / len(records) if len(records) else 0.0
    if mature.empty:
        return {
            "status": "pending_labels",
            "sample_count": len(records),
            "mature_count": 0,
            "label_coverage": coverage,
        }

    mature["correct"] = mature["prediction"].astype("int64") == mature["label"].astype("int64")
    subgroups: dict[str, dict[str, object]] = {}
    for group, rows in mature.groupby("group", sort=True):
        subgroups[str(group)] = {
            "count": len(rows),
            "accuracy": float(rows["correct"].mean()),
            "enough_evidence": len(rows) >= minimum_group_size,
        }
    eligible = [float(item["accuracy"]) for item in subgroups.values() if item["enough_evidence"]]
    gap = max(eligible) - min(eligible) if len(eligible) >= 2 else None
    return {
        "status": "available" if coverage == 1.0 else "partial_labels",
        "sample_count": len(records),
        "mature_count": len(mature),
        "label_coverage": coverage,
        "accuracy": float(mature["correct"].mean()),
        "subgroups": subgroups,
        "eligible_accuracy_gap": gap,
    }


def validate_model_card(card: dict[str, object]) -> None:
    required = {
        "model_name",
        "model_version",
        "intended_use",
        "prohibited_uses",
        "known_limitations",
        "human_override",
        "monitoring_plan",
        "owner",
    }
    missing = required - set(card)
    if missing:
        raise ValueError(f"model card missing: {sorted(missing)}")
    if not card["prohibited_uses"] or not card["human_override"]:
        raise ValueError("prohibited uses and human override must be explicit")


def synthetic_monitoring_report(
    reference_values: Sequence[float],
    current_values: Sequence[float],
    records: pd.DataFrame,
    card: dict[str, object],
) -> dict[str, object]:
    validate_model_card(card)
    edges = [-np.inf, 0.5, 1.5, np.inf]
    reference_bins = fixed_bin_proportions(reference_values, edges)
    current_bins = fixed_bin_proportions(current_values, edges)
    distance = total_variation(reference_bins, current_bins)
    quality = quality_report(records)
    gap = quality.get("eligible_accuracy_gap")
    return {
        "reference_mean": float(np.mean(reference_values)),
        "current_mean": float(np.mean(current_values)),
        "reference_bins": reference_bins.tolist(),
        "current_bins": current_bins.tolist(),
        "input_tv": distance,
        "input_drift_alert": distance >= 0.25,
        "input_claim": "distribution_signal_only_not_quality_proof",
        "quality": quality,
        "subgroup_alert": isinstance(gap, float) and gap >= 0.20,
        "human_override": card["human_override"],
    }
