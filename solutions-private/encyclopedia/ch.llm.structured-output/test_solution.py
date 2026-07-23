from enum import StrEnum
from typing import Literal

import pytest
from pydantic import BaseModel, ConfigDict, ValidationError


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


def test_solution_accepts_exact_contract() -> None:
    value = parse('{"schema_version":"classification/1","category":"OTHER","priority":"LOW"}')
    assert value.priority is Priority.LOW


@pytest.mark.parametrize("raw", [
    '{"category":"OTHER","priority":"LOW"}',
    '{"schema_version":"classification/1","category":"OTHER","priority":"HIGH","x":1}',
    'not-json',
])
def test_solution_rejects_invalid(raw: str) -> None:
    with pytest.raises(ValidationError):
        parse(raw)
