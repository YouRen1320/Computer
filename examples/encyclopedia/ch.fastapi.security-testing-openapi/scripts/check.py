"""Verify authentication, authorization, output filtering and OpenAPI security."""

from __future__ import annotations

import pathlib
import sys
from importlib.metadata import version

from fastapi.testclient import TestClient


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from app import app


assert sys.version_info[:2] == (3, 14)
assert version("fastapi") == "0.139.2"
assert version("pydantic") == "2.13.4"
assert version("starlette") == "1.3.1"
assert version("httpx") == "0.28.1"

with TestClient(app) as client:
    anonymous = client.get("/internal/v1/suggestions/S-1")
    assert anonymous.status_code == 401
    assert anonymous.headers["www-authenticate"] == "Bearer"

    wrong_scheme = client.get(
        "/internal/v1/suggestions/S-1",
        headers={"Authorization": "Basic abc"},
    )
    assert wrong_scheme.status_code == 401

    expired = client.get(
        "/internal/v1/suggestions/S-1",
        headers={"Authorization": "Bearer training-expired"},
    )
    assert expired.status_code == 401

    forbidden = client.get(
        "/internal/v1/suggestions/S-1",
        headers={"Authorization": "Bearer training-denied"},
    )
    assert forbidden.status_code == 403

    hidden_cross_tenant = client.get(
        "/internal/v1/suggestions/S-2",
        headers={"Authorization": "Bearer training-reader"},
    )
    assert hidden_cross_tenant.status_code == 404

    allowed = client.get(
        "/internal/v1/suggestions/S-1",
        headers={"Authorization": "Bearer training-reader"},
    )
    assert allowed.status_code == 200
    assert allowed.json() == {
        "id": "S-1",
        "work_order_id": "WO-001",
        "summary": "Inspect the pump seal",
    }
    assert "internal_score" not in allowed.json()

schema = app.openapi()
operation = schema["paths"]["/internal/v1/suggestions/{suggestion_id}"]["get"]
security_scheme = schema["components"]["securitySchemes"]["TrainingBearer"]
assert security_scheme["type"] == "http"
assert security_scheme["scheme"] == "bearer"
assert operation["security"] == [{"TrainingBearer": []}]
assert operation["operationId"] == "getInternalSuggestion"
assert set(operation["responses"]) >= {"200", "401", "403", "404"}
assert schema["components"]["schemas"]["SuggestionResponse"]["examples"][0]["id"] == "S-1"

operation_ids = [
    method["operationId"]
    for path in schema["paths"].values()
    for method in path.values()
    if isinstance(method, dict) and "operationId" in method
]
assert len(operation_ids) == len(set(operation_ids))
print("PASS: local auth matrix, tenant authorization, response filter and OpenAPI security")
