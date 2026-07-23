import json
from enum import StrEnum
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class Priority(StrEnum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class ClassificationV1(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    schema_version: Literal["work-order-classification/1"]
    category: Literal["MECHANICAL", "ELECTRICAL", "OTHER"]
    priority: Priority
    rationale: str = Field(min_length=1, max_length=160)


value = ClassificationV1.model_validate_json(json.dumps({
    "schema_version": "work-order-classification/1",
    "category": "MECHANICAL",
    "priority": "HIGH",
    "rationale": "Abnormal vibration can damage the bearing.",
}))
assert value.priority is Priority.HIGH
assert ClassificationV1.model_json_schema()["additionalProperties"] is False
print(value.model_dump(mode="json"))
