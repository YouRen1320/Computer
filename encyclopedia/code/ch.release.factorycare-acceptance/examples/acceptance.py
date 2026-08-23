"""Pure acceptance-contract checks for a synthetic FactoryCare release."""

from __future__ import annotations

import re
from typing import Any


DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
REQUIRED_CLIENTS = {"web", "miniapp", "flutter"}


def validate_release(report: dict[str, Any]) -> list[str]:
    """Return human-readable violations; an empty list is the local oracle."""
    errors: list[str] = []
    artifacts = report.get("artifacts", {})
    if not artifacts:
        errors.append("artifacts are required")
    for name, digest in artifacts.items():
        if not DIGEST.fullmatch(str(digest)):
            errors.append(f"{name} does not use an immutable sha256 digest")

    clients = report.get("clients", {})
    if set(clients) != REQUIRED_CLIENTS:
        errors.append("web, miniapp and flutter evidence are all required")
    contract = report.get("api_contract")
    for name, record in clients.items():
        if record.get("contract") != contract or record.get("result") != "pass":
            errors.append(f"{name} did not pass the shared API contract")

    if report.get("cross_tenant_leaks") != 0:
        errors.append("cross-tenant leak count must be zero")
    if report.get("ai_unavailable", {}).get("core_work_order_flow") != "pass":
        errors.append("core work-order flow must pass while AI is unavailable")
    if report.get("rollback", {}).get("result") != "pass":
        errors.append("rollback evidence is missing")
    if report.get("restore", {}).get("result") != "pass":
        errors.append("database restore evidence is missing")
    return errors
