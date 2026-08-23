#!/usr/bin/env bash
set -euo pipefail

uv run --isolated \
  --with 'numpy==2.5.0' \
  --with 'pandas==3.0.5' \
  --with 'pytest==9.1.1' \
  python - <<'PY'
import math

import numpy as np
import pandas as pd
import pytest


actual_reg = np.array([2.0, 4.0])
predicted_reg = np.array([1.0, 7.0])
absolute_errors = np.abs(actual_reg - predicted_reg)
mae = float(absolute_errors.mean())
rmse = float(np.sqrt(np.mean((actual_reg - predicted_reg) ** 2)))
assert mae == pytest.approx(2.0)
assert rmse == pytest.approx(math.sqrt(5.0))

actual = np.array([1, 1, 0, 0])
predicted = np.array([1, 0, 1, 0])
tp = int(np.sum((actual == 1) & (predicted == 1)))
fn = int(np.sum((actual == 1) & (predicted == 0)))
fp = int(np.sum((actual == 0) & (predicted == 1)))
tn = int(np.sum((actual == 0) & (predicted == 0)))
assert (tp, fp, fn, tn) == (1, 1, 1, 1)
precision = tp / (tp + fp)
recall = tp / (tp + fn)
f1 = 2 * precision * recall / (precision + recall)
assert precision == recall == f1 == pytest.approx(0.5)
assert tp + fp + fn + tn == len(actual)

# AUC 的正负样本成对排序手算：四对中三对正确。
positive_scores = np.array([0.9, 0.4])
negative_scores = np.array([0.6, 0.1])
wins = sum(float(pos > neg) + 0.5 * float(pos == neg) for pos in positive_scores for neg in negative_scores)
auc = wins / (len(positive_scores) * len(negative_scores))
assert auc == pytest.approx(0.75)

assert np.__version__ == "2.5.0"
assert pd.__version__ == "3.0.5"
assert pytest.__version__ == "9.1.1"
print("PASS metrics example: MAE/RMSE, confusion metrics and pairwise ROC AUC hand oracles")
PY
