#!/usr/bin/env bash
set -euo pipefail

# 故障注入：四类无监督解释错误被识别后稳定返回 41。
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


raw_features = np.array([
    [1000.0, 0.01],
    [2000.0, 0.90],
    [3000.0, 0.02],
    [4000.0, 0.89],
])
cluster_ids = np.array([0, 1, 0, 1])
risk_by_cluster = {0: "LOW", 1: "HIGH"}
evidence = ["two_dimensional_scatter_plot"]
seed_runs = 1
data_version = None

findings: list[str] = []
column_ranges = np.ptp(raw_features, axis=0)
if float(column_ranges.max() / column_ranges.min()) > 1000:
    findings.append("distance dominated: raw features with incompatible scales were clustered")
if set(risk_by_cluster) == set(np.unique(cluster_ids)):
    findings.append("cluster overreach: arbitrary cluster ids were mapped directly to risk levels")
if evidence == ["two_dimensional_scatter_plot"]:
    findings.append("projection overclaim: a 2D plot was the only evidence")
if seed_runs == 1 or data_version is None:
    findings.append("stability missing: one seed and no data version cannot support drift claims")

assert findings == [
    "distance dominated: raw features with incompatible scales were clustered",
    "cluster overreach: arbitrary cluster ids were mapped directly to risk levels",
    "projection overclaim: a 2D plot was the only evidence",
    "stability missing: one seed and no data version cannot support drift claims",
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
