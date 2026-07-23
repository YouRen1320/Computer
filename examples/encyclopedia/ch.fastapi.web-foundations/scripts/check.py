"""Verify routing, validation, output filtering and dependency overrides."""

from __future__ import annotations

import pathlib
import sys
from importlib.metadata import version

from fastapi.testclient import TestClient


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from app import TrainingRepository, app, get_repository


assert version("fastapi") == "0.139.2"
assert version("pydantic") == "2.13.4"
assert version("starlette") == "1.3.1"
assert version("httpx") == "0.28.1"

with TestClient(app) as client:
    assert client.get("/health").json() == {"status": "ok"}
    assert client.get("/training/work-orders/special").json() == {"kind": "special"}

    found = client.get("/training/work-orders/WO-001")
    assert found.status_code == 200
    assert found.json() == {"id": "WO-001", "title": "Inspect pump", "priority": 4}
    assert "internal_secret" not in found.json()

    missing = client.get("/training/work-orders/WO-404")
    assert missing.status_code == 404
    assert missing.json() == {"detail": "training order not found"}

    created = client.post(
        "/training/work-orders",
        json={"title": "Calibrate sensor", "priority": 3},
    )
    assert created.status_code == 201
    assert created.json() == {"id": "WO-002", "title": "Calibrate sensor", "priority": 3}

    invalid = client.post(
        "/training/work-orders",
        json={"title": "Bad priority", "priority": 9},
    )
    assert invalid.status_code == 422
    assert invalid.json()["code"] == "REQUEST_INVALID"
    assert any(error["location"][-1] == "priority" for error in invalid.json()["errors"])

    extra = client.post(
        "/training/work-orders",
        json={"title": "Hidden", "priority": 2, "tenant_id": "attacker"},
    )
    assert extra.status_code == 422


class OverrideRepository(TrainingRepository):
    def get(self, order_id: str) -> dict[str, object] | None:
        return {"id": order_id, "title": "Overridden", "priority": 1}


try:
    app.dependency_overrides[get_repository] = OverrideRepository
    with TestClient(app) as client:
        overridden = client.get("/training/work-orders/WO-TEST")
    assert overridden.json() == {"id": "WO-TEST", "title": "Overridden", "priority": 1}
finally:
    app.dependency_overrides.clear()

assert app.dependency_overrides == {}
print("PASS: FastAPI routing, validation, response filtering and dependency override")
