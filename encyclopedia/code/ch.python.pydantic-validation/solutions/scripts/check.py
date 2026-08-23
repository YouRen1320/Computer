from __future__ import annotations

import importlib.util
import pathlib
import sys

import pydantic
from pydantic import ValidationError


root = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("pydantic_solution", root / "solution.py")
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
model = module.WorkOrderContract

valid = model.model_validate({"workOrderId": 7, "priority": 4})
assert valid.model_dump(mode="json", by_alias=True) == {
    "workOrderId": 7,
    "priority": 4,
    "escalation_reason": None,
}

for payload in (
    {"workOrderId": "7", "priority": 4},
    {"workOrderId": 7, "priority": 4, "prioritty": 5},
    {"workOrderId": 7, "priority": 5},
    {"workOrderId": 0, "priority": 4},
    {"workOrderId": 7, "priority": 6},
):
    try:
        model.model_validate(payload)
    except ValidationError:
        pass
    else:
        raise AssertionError(f"invalid payload accepted: {payload}")

model.model_validate(
    {"workOrderId": 7, "priority": 5, "escalation_reason": "safety"}
)
schema = model.model_json_schema(by_alias=True)
assert set(schema["properties"]) == {
    "workOrderId",
    "priority",
    "escalation_reason",
}
assert schema["additionalProperties"] is False
assert pydantic.__version__ == "2.13.4"
print("PASS private pydantic solution: strict, extra, alias and cross-field contracts")
