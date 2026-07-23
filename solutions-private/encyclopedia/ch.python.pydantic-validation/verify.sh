#!/usr/bin/env bash
set -euo pipefail

uv run --isolated \
  --with 'pydantic==2.13.4' \
  --with 'pytest==9.1.1' \
  python - <<'PY'
from typing import Self

import pydantic
import pytest
from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator


class WorkOrderContract(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")

    work_order_id: int = Field(
        validation_alias="workOrderId",
        serialization_alias="workOrderId",
        gt=0,
    )
    priority: int = Field(ge=1, le=5)
    escalation_reason: str | None = None

    @model_validator(mode="after")
    def urgent_requires_reason(self) -> Self:
        if self.priority == 5 and not self.escalation_reason:
            raise ValueError("priority 5 requires escalation_reason")
        return self


valid = WorkOrderContract.model_validate({"workOrderId": 7, "priority": 4})
assert valid.model_dump(mode="json", by_alias=True) == {
    "workOrderId": 7,
    "priority": 4,
    "escalation_reason": None,
}

with pytest.raises(ValidationError) as strict_error:
    WorkOrderContract.model_validate({"workOrderId": "7", "priority": 4})
assert strict_error.value.errors(include_input=False)[0]["type"] == "int_type"

with pytest.raises(ValidationError) as extra_error:
    WorkOrderContract.model_validate({"workOrderId": 7, "priority": 4, "prioritty": 5})
assert extra_error.value.errors(include_input=False)[0]["type"] == "extra_forbidden"

with pytest.raises(ValidationError) as cross_field_error:
    WorkOrderContract.model_validate({"workOrderId": 7, "priority": 5})
assert cross_field_error.value.errors(include_input=False)[0]["type"] == "value_error"

schema = WorkOrderContract.model_json_schema(by_alias=True)
assert set(schema["properties"]) == {"workOrderId", "priority", "escalation_reason"}
assert schema["additionalProperties"] is False
assert pydantic.__version__ == "2.13.4"
assert pytest.__version__ == "9.1.1"
print("PASS private pydantic solution: strict/extra/alias/cross-field contracts are fixed")
PY
