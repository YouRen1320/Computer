"""Verify the private solution's runtime and OpenAPI security contracts."""

from __future__ import annotations

import pathlib
import sys

from fastapi.testclient import TestClient


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from app import app


assert sys.version_info[:2] == (3, 14)

with TestClient(app) as client:
    anonymous = client.get("/internal/v1/suggestions/S-1")
    assert anonymous.status_code == 401
    assert anonymous.headers["www-authenticate"] == "Bearer"

    forbidden = client.get(
        "/internal/v1/suggestions/S-1",
        headers={"Authorization": "Bearer training-denied"},
    )
    assert forbidden.status_code == 403

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
assert operation["security"] == [{"TrainingBearer": []}]
assert schema["components"]["securitySchemes"]["TrainingBearer"]["scheme"] == "bearer"
print("PASS: auth dependency, permission check, response filter and OpenAPI security")
