#!/usr/bin/env bash
set -euo pipefail

# 故障注入：四类建模合同错误被识别后稳定返回 41。
set +e
uv run --isolated \
  --with 'numpy==2.5.0' \
  --with 'pandas==3.0.5' \
  --with 'pytest==9.1.1' \
  python - <<'PY'
import ast
import sys

import numpy as np
import pandas as pd
import pytest


BROKEN_SOURCE = '''
task = "regression"
labels = ["LOW", "HIGH", "LOW"]
report = {"train_score": 1.0}

def classify(probability):
    return int(probability >= 0.5)

regularization_claim = "stronger penalty increases coefficient norm"
'''

tree = ast.parse(BROKEN_SOURCE, filename="broken_supervised.py")
namespace: dict[str, object] = {}
exec(compile(tree, "broken_supervised.py", "exec"), namespace)
findings: list[str] = []

if namespace["task"] == "regression" and all(isinstance(value, str) for value in namespace["labels"]):
    findings.append("task mismatch: nominal labels were assigned to numeric regression")
if "train_score" in namespace["report"] and not any(key.startswith("holdout") for key in namespace["report"]):
    findings.append("generalization missing: report contains only a training score")

classify_node = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "classify")
if any(isinstance(node, ast.Constant) and node.value == 0.5 for node in ast.walk(classify_node)):
    findings.append("threshold hidden: 0.5 is hard-coded inside model decision code")
if "increases coefficient norm" in namespace["regularization_claim"]:
    findings.append("regularization direction wrong: stronger penalty was claimed to enlarge coefficients")

assert findings == [
    "task mismatch: nominal labels were assigned to numeric regression",
    "generalization missing: report contains only a training score",
    "threshold hidden: 0.5 is hard-coded inside model decision code",
    "regularization direction wrong: stronger penalty was claimed to enlarge coefficients",
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
