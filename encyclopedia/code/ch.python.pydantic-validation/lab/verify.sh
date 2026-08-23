#!/usr/bin/env bash
set -euo pipefail

uv run --isolated \
  --with 'pydantic==2.13.4' \
  --with 'pytest==9.1.1' \
  python - <<'PY'
import json
from typing import Self

import pydantic
import pytest
from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator, model_validator


class WorkOrderCreate(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")

    work_order_id: int = Field(
        validation_alias="workOrderId",
        serialization_alias="workOrderId",
        gt=0,
    )
    title: str = Field(min_length=1, max_length=120)
    priority: int = Field(ge=1, le=5)
    escalation_reason: str | None = None

    @field_validator("title", mode="after")
    @classmethod
    def normalize_title(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("title must contain visible text")
        return normalized

    @model_validator(mode="after")
    def urgent_requires_reason(self) -> Self:
        if self.priority == 5 and not self.escalation_reason:
            raise ValueError("priority 5 requires escalation_reason")
        return self


def safe_errors(error: ValidationError) -> list[dict[str, object]]:
    normalized = [
        {
            "path": [str(part) for part in item["loc"]],
            "code": item["type"],
        }
        for item in error.errors(include_input=False)
    ]
    return sorted(normalized, key=lambda item: (item["path"], item["code"]))


def assert_error(payload: object, path: list[str], code: str) -> None:
    with pytest.raises(ValidationError) as caught:
        WorkOrderCreate.model_validate(payload)
    errors = safe_errors(caught.value)
    assert {"path": path, "code": code} in errors, errors
    snapshot = json.dumps(errors, ensure_ascii=False, sort_keys=True)
    assert "secret-value" not in snapshot
    assert "input" not in snapshot


valid = WorkOrderCreate.model_validate_json(json.dumps({
    "workOrderId": 11,
    "title": "  Cooling pump  ",
    "priority": 5,
    "escalation_reason": "temperature rising",
}))
assert valid.title == "Cooling pump"
wire = valid.model_dump(mode="json", by_alias=True)
assert wire == {
    "workOrderId": 11,
    "title": "Cooling pump",
    "priority": 5,
    "escalation_reason": "temperature rising",
}
assert WorkOrderCreate.model_validate(wire) == valid

assert_error(
    {"workOrderId": 11, "priority": 4},
    ["title"],
    "missing",
)
assert_error(
    {"workOrderId": 11, "title": "Pump", "priority": 4, "secret": "secret-value"},
    ["secret"],
    "extra_forbidden",
)
assert_error(
    {"workOrderId": "11", "title": "Pump", "priority": 4},
    ["workOrderId"],
    "int_type",
)
assert_error(
    {"workOrderId": 11, "title": "Pump", "priority": 5},
    [],
    "value_error",
)

schema = WorkOrderCreate.model_json_schema(by_alias=True)
assert schema["required"] == ["workOrderId", "title", "priority"]
assert schema["additionalProperties"] is False
assert schema["properties"]["priority"]["minimum"] == 1
assert schema["properties"]["priority"]["maximum"] == 5
assert pydantic.__version__ == "2.13.4"
assert pytest.__version__ == "9.1.1"
print("PASS pydantic lab: valid/missing/extra/type/cross-field/roundtrip/schema/error snapshot")
PY
