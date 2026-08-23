"""Behavioral and schema oracle for the editable Pydantic model."""

from __future__ import annotations

import importlib.util
import pathlib
import sys
import traceback
from types import ModuleType

import pydantic
from pydantic import ValidationError


def load_submission(path: pathlib.Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("pydantic_submission", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def rejected(model: type, payload: dict[str, object]) -> bool:
    try:
        model.model_validate(payload)
    except ValidationError:
        return True
    return False


def inspect_contract(model: type) -> list[str]:
    problems: list[str] = []
    try:
        valid = model.model_validate({"workOrderId": 7, "priority": 4})
    except ValidationError:
        problems.append("valid-payload-rejected")
        return problems

    expected_dump = {
        "workOrderId": 7,
        "priority": 4,
        "escalation_reason": None,
    }
    if valid.model_dump(mode="json", by_alias=True) != expected_dump:
        problems.append("alias-json-output-drift")
    if not rejected(model, {"workOrderId": "7", "priority": 4}):
        problems.append("string-to-int-coercion")
    if not rejected(model, {"workOrderId": 7, "priority": 4, "prioritty": 5}):
        problems.append("extra-field-ignored")
    if not rejected(model, {"workOrderId": 7, "priority": 5}):
        problems.append("urgent-reason-not-required")
    if rejected(
        model,
        {"workOrderId": 7, "priority": 5, "escalation_reason": "safety"},
    ):
        problems.append("urgent-reason-valid-payload-rejected")
    if not rejected(model, {"workOrderId": 0, "priority": 4}):
        problems.append("non-positive-id-accepted")
    if not rejected(model, {"workOrderId": 7, "priority": 6}):
        problems.append("priority-range-not-enforced")

    schema = model.model_json_schema(by_alias=True)
    if set(schema.get("properties", {})) != {
        "workOrderId",
        "priority",
        "escalation_reason",
    }:
        problems.append("schema-alias-drift")
    if schema.get("additionalProperties") is not False:
        problems.append("schema-allows-extra-properties")
    return problems


def main() -> int:
    try:
        root = pathlib.Path(__file__).resolve().parents[1]
        module = load_submission(root / "exercise.py")
        problems = inspect_contract(module.WorkOrderContract)
    except Exception:  # Non-contract failure: preserve diagnostics for exit 43 mapping.
        traceback.print_exc()
        return 70

    if pydantic.__version__ != "2.13.4":
        print(f"unexpected pydantic version: {pydantic.__version__}", file=sys.stderr)
        return 70
    if problems:
        print(
            "EXPECTED_PYTHON_PYDANTIC_VALIDATION_RED problems=" + ",".join(problems),
            file=sys.stderr,
        )
        return 1
    print("PYTHON_PYDANTIC_VALIDATION_EXERCISE_PASS checks=9")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
