"""Executable negative security matrix and OpenAPI contract checks."""

from __future__ import annotations

import json
import sys
from importlib.metadata import version
from pathlib import Path

import pytest
from httpx import ASGITransport, AsyncClient

from app import Principal, create_app, current_principal


@pytest.fixture
def anyio_backend() -> str:
    # Fix the backend so this lab does not silently require Trio.
    return "asyncio"


@pytest.fixture
def app():
    return create_app()


@pytest.fixture
async def client(app):
    # ASGITransport runs requests in-process; it does not prove real network behavior.
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as session:
        yield session


@pytest.mark.anyio
async def test_authentication_and_authorization_matrix(client, app) -> None:
    anonymous = await client.get("/internal/v1/suggestions/S-1")
    assert anonymous.status_code == 401
    assert anonymous.headers["www-authenticate"] == "Bearer"

    wrong_scheme = await client.get(
        "/internal/v1/suggestions/S-1",
        headers={"Authorization": "Basic abc"},
    )
    assert wrong_scheme.status_code == 401

    unknown = await client.get(
        "/internal/v1/suggestions/S-1",
        headers={"Authorization": "Bearer unknown"},
    )
    assert unknown.status_code == 401

    expired = await client.get(
        "/internal/v1/suggestions/S-1",
        headers={"Authorization": "Bearer training-expired"},
    )
    assert expired.status_code == 401

    forbidden = await client.get(
        "/internal/v1/suggestions/S-1",
        headers={"Authorization": "Bearer training-denied"},
    )
    assert forbidden.status_code == 403

    # Authentication/operation authorization failures stop before repository access.
    assert app.state.repository.read_count == 0

    cross_tenant = await client.get(
        "/internal/v1/suggestions/S-2",
        headers={"Authorization": "Bearer training-reader"},
    )
    assert cross_tenant.status_code == 404

    allowed = await client.get(
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


@pytest.mark.anyio
async def test_dependency_override_is_scoped_and_cleaned(client, app) -> None:
    async def tenant_two_reader() -> Principal:
        return Principal(
            subject="test-user",
            tenant_id="tenant-2",
            permissions=frozenset({"suggestions:read"}),
        )

    try:
        app.dependency_overrides[current_principal] = tenant_two_reader
        overridden = await client.get("/internal/v1/suggestions/S-2")
        assert overridden.status_code == 200
        assert overridden.json()["id"] == "S-2"
    finally:
        app.dependency_overrides.clear()

    assert app.dependency_overrides == {}
    anonymous_again = await client.get("/internal/v1/suggestions/S-1")
    assert anonymous_again.status_code == 401


def test_openapi_projection_matches_reviewed_baseline(app) -> None:
    schema = app.openapi()
    operation = schema["paths"]["/internal/v1/suggestions/{suggestion_id}"]["get"]
    projection = {
        "openapi": schema["openapi"],
        "operationId": operation["operationId"],
        "security": operation["security"],
        "responseCodes": sorted(operation["responses"]),
        "securityScheme": schema["components"]["securitySchemes"]["TrainingBearer"],
    }
    baseline = json.loads(
        Path(__file__).with_name("contract_baseline.json").read_text(encoding="utf-8")
    )
    assert projection == baseline
    assert schema["components"]["schemas"]["SuggestionResponse"]["examples"]


def test_runtime_versions_are_the_reviewed_combination() -> None:
    assert sys.version_info[:2] == (3, 14)
    assert version("fastapi") == "0.139.2"
    assert version("pydantic") == "2.13.4"
    assert version("starlette") == "1.3.1"
    assert version("httpx") == "0.28.1"
    assert version("pytest") == "9.1.1"
    assert version("anyio") == "4.14.2"
