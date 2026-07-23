"""Executable oracle for the chapter's controlled, local-only fixture."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).parent
DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")


def audit(report: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    contract = report.get("api_contract")
    clients = report.get("clients", {})
    if set(clients) != {"web", "miniapp", "flutter"}:
        errors.append("three client records are required")
    for name, record in clients.items():
        if record != {"contract": contract, "result": "pass"}:
            errors.append(f"client contract drift: {name}")
    for name, digest in report.get("artifacts", {}).items():
        if not DIGEST.fullmatch(str(digest)):
            errors.append(f"mutable artifact identity: {name}")
    if report.get("security", {}).get("cross_tenant_leaks") != 0:
        errors.append("tenant isolation failed")
    ai = report.get("ai_outage", {})
    if ai.get("core_flow") != "pass" or ai.get("degraded_feature") != "retryable":
        errors.append("AI outage blocked core flow or was not observable")
    if report.get("canary", {}) != {"identity_match": True, "result": "pass"}:
        errors.append("canary identity or gate failed")
    rollback = report.get("rollback", {})
    if not rollback.get("previous_digest_restored") or rollback.get("smoke") != "pass":
        errors.append("rollback was not proven")
    restore = report.get("restore", {})
    if restore.get("integrity") != "pass" or not restore.get("rto_measured") or not restore.get("rpo_measured"):
        errors.append("restore integrity/RTO/RPO evidence is incomplete")
    return errors


if __name__ == "__main__":
    fixture = json.loads((ROOT / "acceptance.fixture.json").read_text(encoding="utf-8"))
    found = audit(fixture)
    if found:
        raise SystemExit("\n".join(found))
    print("PASS controlled FactoryCare acceptance-manifest fixture")
    print("UNVERIFIED real services, Docker, registry, TLS, PostgreSQL, devices, model API, canary and disaster recovery")
