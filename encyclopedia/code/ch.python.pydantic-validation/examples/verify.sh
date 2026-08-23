#!/usr/bin/env bash
set -euo pipefail

uv run --isolated \
  --with 'pydantic==2.13.4' \
  --with 'pytest==9.1.1' \
  python - <<'PY'
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


model = WorkOrderCreate.model_validate({
    "workOrderId": 7,
    "title": "  Pump alarm  ",
    "priority": 5,
    "escalation_reason": "safety risk",
})
assert model.title == "Pump alarm"
assert model.model_dump(mode="json", by_alias=True) == {
    "workOrderId": 7,
    "title": "Pump alarm",
    "priority": 5,
    "escalation_reason": "safety risk",
}

with pytest.raises(ValidationError) as extra_error:
    WorkOrderCreate.model_validate({
        "workOrderId": 7,
        "title": "Pump alarm",
        "priority": 4,
        "unknown": "must fail",
    })
assert extra_error.value.errors(include_input=False)[0]["type"] == "extra_forbidden"

with pytest.raises(ValidationError) as strict_error:
    WorkOrderCreate.model_validate({
        "workOrderId": "7",
        "title": "Pump alarm",
        "priority": 4,
    })
assert strict_error.value.errors(include_input=False)[0]["type"] == "int_type"

schema = WorkOrderCreate.model_json_schema(by_alias=True)
assert "workOrderId" in schema["properties"]
assert "work_order_id" not in schema["properties"]
assert pydantic.__version__ == "2.13.4"
assert pytest.__version__ == "9.1.1"
print("PASS pydantic example: strict input, extra forbid, validators, alias, dump and schema")
PY
