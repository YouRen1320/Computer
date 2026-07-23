#!/usr/bin/env bash
set -euo pipefail

# 故障注入：四类评价失真被识别后稳定返回 41。
set +e
uv run --isolated \
  --with 'numpy==2.5.0' \
  --with 'pandas==3.0.5' \
  --with 'pytest==9.1.1' \
  python - <<'PY'
import sys

import numpy as np
import pandas as pd
import pytest


actual = np.array([1] * 5 + [0] * 95)
predicted = np.zeros(100, dtype=int)
accuracy = float(np.mean(actual == predicted))
recall = float(np.sum((actual == 1) & (predicted == 1)) / np.sum(actual == 1))

groups = np.repeat(np.arange(10), 2)
train_indices = np.arange(0, 20, 2)
validation_indices = np.arange(1, 20, 2)
fold_scores = [0.61, 0.95, 0.60]
reported_score = max(fold_scores)
report = {"score": reported_score}

findings: list[str] = []
if accuracy >= 0.95 and recall == 0.0:
    findings.append("metric mismatch: high accuracy hides zero minority recall")
if not set(groups[train_indices]).isdisjoint(set(groups[validation_indices])):
    findings.append("cross-validation leakage: the same entity appears in train and validation")
if reported_score == max(fold_scores) and reported_score != pytest.approx(float(np.mean(fold_scores))):
    findings.append("selective reporting: only the best fold was reported")
if "baseline" not in report or "predeclared_gate" not in report:
    findings.append("decision evidence missing: no baseline or predeclared business gate")

assert findings == [
    "metric mismatch: high accuracy hides zero minority recall",
    "cross-validation leakage: the same entity appears in train and validation",
    "selective reporting: only the best fold was reported",
    "decision evidence missing: no baseline or predeclared business gate",
]
assert np.__version__ == "2.5.0"
assert pd.__version__ == "3.0.5"
assert pytest.__version__ == "9.1.1"
for finding in findings:
    print(f"[EXPECTED FAILURE] {finding}", file=sys.stderr)
sys.exit(41)
PY
exercise_status=$?
set -e

if [[ "$exercise_status" -ne 41 ]]; then
  echo "exercise oracle drift: expected exit 41, got $exercise_status" >&2
  exit 42
fi
exit 41
