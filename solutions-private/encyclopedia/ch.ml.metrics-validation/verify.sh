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


actual = np.array([1, 1, 1, 0, 0, 0])
probability = np.array([0.9, 0.7, 0.4, 0.6, 0.2, 0.1])
predicted = (probability >= 0.4).astype(int)
tp = int(np.sum((actual == 1) & (predicted == 1)))
fp = int(np.sum((actual == 0) & (predicted == 1)))
fn = int(np.sum((actual == 1) & (predicted == 0)))
tn = int(np.sum((actual == 0) & (predicted == 0)))
assert (tp, fp, fn, tn) == (3, 1, 0, 2)
recall = tp / (tp + fn)
precision = tp / (tp + fp)
assert recall == pytest.approx(1.0)
assert precision == pytest.approx(0.75)

groups = np.repeat(np.array(["A", "B", "C"]), 2)
fold_scores = []
for validation_group in np.unique(groups):
    validation = groups == validation_group
    train = ~validation
    assert set(groups[train]).isdisjoint(set(groups[validation]))
    fold_scores.append(float(np.mean(predicted[validation] == actual[validation])))
reported = float(np.mean(fold_scores))
assert reported != max(fold_scores)

baseline_cost = 5 * int(actual.sum())
model_cost = 5 * fn + fp
report = {
    "baseline": "predict no positives",
    "predeclared_gate": "recall >= 0.9 and cost below baseline",
    "recall": recall,
    "cost": model_cost,
}
assert report["recall"] >= 0.9
assert report["cost"] < baseline_cost

assert np.__version__ == "2.5.0"
assert pd.__version__ == "3.0.5"
assert pytest.__version__ == "9.1.1"
print("PASS private metrics solution: minority metric, group split, all-fold aggregation and baseline gate fixed")
PY
