"""Expected-red oracle for response filtering and OpenAPI response schema."""

from __future__ import annotations

import pathlib
import sys

from fastapi.testclient import TestClient


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from app import app


with TestClient(app) as client:
    response = client.get("/training/work-orders/WO-001")

assert response.status_code == 200
assert response.json() == {
    "id": "WO-001",
    "title": "Inspect pump",
    "priority": 4,
}, f"EXPECTED RED: public response leaked or drifted: {response.json()!r}"

operation = app.openapi()["paths"]["/training/work-orders/{order_id}"]["get"]
schema = operation["responses"]["200"]["content"]["application/json"]["schema"]
assert "$ref" in schema, f"EXPECTED RED: response lacks named model: {schema!r}"
print("PASS: response model filters internal data and documents a named schema")
