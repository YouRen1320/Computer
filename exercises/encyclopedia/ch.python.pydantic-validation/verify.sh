#!/usr/bin/env bash
set -euo pipefail

# 这是故障注入练习：三个合同漂移被证实后稳定返回 41。
set +e
uv run --isolated \
  --with 'pydantic==2.13.4' \
  --with 'pytest==9.1.1' \
  python - <<'PY'
import sys

import pydantic
import pytest
from pydantic import BaseModel, Field


class BrokenWorkOrder(BaseModel):
    # 故意没有 strict=True，也没有 extra="forbid"。
    work_order_id: int = Field(
        validation_alias="workOrderId",
        serialization_alias="workOrderId",
    )
    priority: int


payload = {
    "workOrderId": "7",
    "priority": 4,
    "prioritty": 5,
}
model = BrokenWorkOrder.model_validate(payload)
findings: list[str] = []

if model.work_order_id == 7 and isinstance(model.work_order_id, int):
    findings.append("unexpected coercion: string workOrderId became int")
if "prioritty" not in model.model_dump():
    findings.append("extra field silently ignored: prioritty disappeared")
if "work_order_id" in model.model_dump() and "workOrderId" not in model.model_dump():
    findings.append("alias drift: default dump emitted work_order_id")

assert findings == [
    "unexpected coercion: string workOrderId became int",
    "extra field silently ignored: prioritty disappeared",
    "alias drift: default dump emitted work_order_id",
]
assert pydantic.__version__ == "2.13.4"
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
