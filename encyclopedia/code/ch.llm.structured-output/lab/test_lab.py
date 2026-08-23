import json
from enum import StrEnum
from typing import Literal

import pytest
from pydantic import BaseModel, ConfigDict, Field, ValidationError


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


class OutputRejected(RuntimeError):
    def __init__(self, reason: str):
        super().__init__(reason)
        self.reason = reason


def validate_provider_envelope(envelope: dict) -> ClassificationV1:
    if envelope.get("refusal") is not None:
        raise OutputRejected("provider_refusal")
    if envelope.get("status") != "completed":
        raise OutputRejected("provider_incomplete")
    raw = envelope.get("text")
    if not isinstance(raw, str):
        raise OutputRejected("missing_text")
    try:
        return ClassificationV1.model_validate_json(raw)
    except (ValidationError, ValueError, json.JSONDecodeError) as exc:
        # Emit a stable class and field locations; never echo the raw model text.
        if isinstance(exc, ValidationError):
            kind = "invalid_json" if exc.errors()[0]["type"] == "json_invalid" else "schema_validation"
        else:
            kind = "invalid_json"
        raise OutputRejected(kind) from exc


VALID = {"schema_version": "work-order-classification/1", "category": "MECHANICAL",
         "priority": "HIGH", "rationale": "Bearing risk."}


def test_only_validated_value_reaches_business() -> None:
    calls: list[ClassificationV1] = []
    value = validate_provider_envelope({"status": "completed", "refusal": None, "text": json.dumps(VALID)})
    calls.append(value)
    assert calls[0].model_dump(mode="json") == VALID


@pytest.mark.parametrize("mutator", [
    lambda d: d.pop("category"),
    lambda d: d.update(priority="CRITICAL"),
    lambda d: d.update(debug=True),
    lambda d: d.update(schema_version="work-order-classification/2"),
])
def test_rejects_schema_violations(mutator) -> None:
    payload = dict(VALID)
    mutator(payload)
    with pytest.raises(OutputRejected, match="schema_validation"):
        validate_provider_envelope({"status": "completed", "refusal": None, "text": json.dumps(payload)})


@pytest.mark.parametrize("envelope,reason", [
    ({"status": "completed", "refusal": None, "text": "not-json"}, "invalid_json"),
    ({"status": "incomplete", "refusal": None, "text": json.dumps(VALID)}, "provider_incomplete"),
    ({"status": "completed", "refusal": "cannot comply", "text": None}, "provider_refusal"),
])
def test_protocol_failures_are_separate(envelope: dict, reason: str) -> None:
    with pytest.raises(OutputRejected, match=reason):
        validate_provider_envelope(envelope)
