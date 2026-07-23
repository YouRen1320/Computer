"""Acceptance check intentionally fails until the learner wires security."""

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
    assert anonymous.status_code == 401, (
        "exercise incomplete: anonymous access must return 401, "
        f"but returned {anonymous.status_code}"
    )
    assert anonymous.headers["www-authenticate"] == "Bearer"

schema = app.openapi()
operation = schema["paths"]["/internal/v1/suggestions/{suggestion_id}"]["get"]
assert operation["security"] == [{"TrainingBearer": []}]
print("PASS: security dependency and OpenAPI requirement are wired")
