"""Synthetic mixed-version, canary and migration evidence gate."""

from __future__ import annotations

from typing import Any


def audit(record: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if record.get("old_app_contract") != "green" or record.get("new_app_contract") != "green":
        errors.append("expanded schema is not compatible with both app versions")
    if record.get("contract_started") and (
        record.get("old_replica_count", 1) > 0
        or not record.get("backfill_complete")
        or record.get("legacy_read_count", 1) > 0
    ):
        errors.append("contract began before old readers and backfill were retired")
    if record.get("migration_state") != "success" and record.get("traffic_promoted"):
        errors.append("traffic was promoted while migration was not green")
    if record.get("canary_gate") != "green" and record.get("traffic_promoted"):
        errors.append("traffic was promoted past a failed canary")
    if record.get("rollback_to_old_app") and not record.get("legacy_schema_present"):
        errors.append("old artifact cannot read the contracted schema")
    if record.get("artifact_before") != record.get("artifact_after"):
        errors.append("deployment rebuilt instead of promoting one immutable artifact")
    if not record.get("forward_fix_verified"):
        errors.append("database failure has no verified forward-fix convergence")
    return errors


GOOD_RECORD = {
    "old_app_contract": "green",
    "new_app_contract": "green",
    "contract_started": False,
    "old_replica_count": 1,
    "backfill_complete": True,
    "legacy_read_count": 1,
    "migration_state": "success",
    "canary_gate": "green",
    "traffic_promoted": True,
    "rollback_to_old_app": False,
    "legacy_schema_present": True,
    "artifact_before": "sha256:immutable-fixture",
    "artifact_after": "sha256:immutable-fixture",
    "forward_fix_verified": True,
}


if __name__ == "__main__":
    problems = audit(GOOD_RECORD)
    if problems:
        raise SystemExit("\n".join(problems))
    print("PASS synthetic mixed-version, canary, rollback-boundary and forward-fix evidence gate")
    print("UNVERIFIED CI, Docker/Compose, Nginx, Flyway, PostgreSQL, DDL locks and real traffic shifting")
