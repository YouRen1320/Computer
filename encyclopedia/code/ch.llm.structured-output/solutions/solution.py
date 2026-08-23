from enum import StrEnum
from typing import Literal

from pydantic import BaseModel, ConfigDict


class Priority(StrEnum):
    LOW = "LOW"
    HIGH = "HIGH"


class ClassificationV1(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    schema_version: Literal["classification/1"]
    category: Literal["MECHANICAL", "OTHER"]
    priority: Priority


def parse(raw: str) -> ClassificationV1:
    return ClassificationV1.model_validate_json(raw)
