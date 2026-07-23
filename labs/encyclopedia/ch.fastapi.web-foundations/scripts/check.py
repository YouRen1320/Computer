"""Verify the CRUD matrix, dependency failures and safe internal errors."""

from __future__ import annotations

import pathlib
import sys

from fastapi.testclient import TestClient


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))

from app import MemoryRepository, RepositoryUnavailable, app, get_repository


with TestClient(app, raise_server_exceptions=False) as client:
    assert client.get("/training/work-orders/special").json() == {"kind": "special"}

    listed = client.get("/training/work-orders", params={"min_priority": 4})
    assert listed.status_code == 200
    assert listed.json() == [{"id": "WO-001", "title": "Inspect pump", "priority": 4}]

    invalid_query = client.get("/training/work-orders", params={"min_priority": 0})
    assert invalid_query.status_code == 422
    assert invalid_query.json()["code"] == "REQUEST_INVALID"

    created = client.post(
        "/training/work-orders",
        json={"id": "WO-010", "title": "Inspect motor", "priority": 4},
    )
    assert created.status_code == 201
    assert created.json() == {"id": "WO-010", "title": "Inspect motor", "priority": 4}

    duplicate = client.post(
        "/training/work-orders",
        json={"id": "WO-010", "title": "Duplicate", "priority": 1},
    )
    assert duplicate.status_code == 409
    assert duplicate.json() == {"code": "ORDER_ALREADY_EXISTS"}

    extra = client.post(
        "/training/work-orders",
        json={"id": "WO-011", "title": "Extra", "priority": 2, "status": "CLOSED"},
    )
    assert extra.status_code == 422

    patched = client.patch(
        "/training/work-orders/WO-010",
        json={"priority": 5},
    )
    assert patched.status_code == 200
    assert patched.json()["priority"] == 5
    assert "internal_secret" not in patched.json()

    missing = client.get("/training/work-orders/WO-999")
    assert missing.status_code == 404

    deleted = client.delete("/training/work-orders/WO-010")
    assert deleted.status_code == 204
    assert deleted.content == b""
    assert client.get("/training/work-orders/WO-010").status_code == 404


class UnavailableRepository(MemoryRepository):
    def get(self, order_id: str) -> dict[str, object] | None:
        raise RepositoryUnavailable(f"database password leaked for {order_id}")


try:
    app.dependency_overrides[get_repository] = UnavailableRepository
    with TestClient(app, raise_server_exceptions=False) as client:
        failed = client.get("/training/work-orders/WO-001")
    assert failed.status_code == 503
    assert failed.json() == {"code": "DEPENDENCY_UNAVAILABLE"}
    assert "password" not in failed.text
finally:
    app.dependency_overrides.clear()

assert app.dependency_overrides == {}
print("PASS: CRUD, validation, conflict, safe dependency error and override cleanup")
