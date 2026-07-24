"""Fault-injection oracle for a synthetic backup/restore evidence record."""

from __future__ import annotations

from datetime import datetime
from typing import Any


def audit(record: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if record.get("backup_exit_code") != 0:
        errors.append("backup command failed")
    if not record.get("manifest_verified"):
        errors.append("exit code alone does not verify backup contents")
    if record.get("backup_failure_domain") == record.get("key_failure_domain"):
        errors.append("backup and key share one failure domain")
    if record.get("target_environment") in {"prod", "production"}:
        errors.append("restore drill targets production")
    if not record.get("target_empty"):
        errors.append("restore target is not empty")
    if not record.get("transaction_consistent"):
        errors.append("snapshot captured a transaction mid-state")
    if not record.get("business_invariants_passed"):
        errors.append("restored business invariants failed")
    if record.get("restored_row_hash") != record.get("expected_row_hash"):
        errors.append("restored row hash differs from backup manifest")
    if not record.get("retention_policy_id"):
        errors.append("retention policy identity is missing")
    try:
        requested_at = datetime.fromisoformat(record["restore_requested_at"])
        delete_after = datetime.fromisoformat(record["delete_after"])
        if requested_at.tzinfo is None or delete_after.tzinfo is None:
            raise ValueError("retention timestamps must include timezone")
        if requested_at > delete_after:
            errors.append("backup expired before restore request")
    except (KeyError, TypeError, ValueError):
        errors.append("retention timestamps are missing or invalid")
    if record.get("rpo_seconds", float("inf")) > record.get("rpo_objective_seconds", -1):
        errors.append("RPO objective missed")
    if record.get("rto_seconds", float("inf")) > record.get("rto_objective_seconds", -1):
        errors.append("RTO objective missed")
    return errors


GOOD_RECORD = {
    "backup_exit_code": 0,
    "manifest_verified": True,
    "backup_failure_domain": "object-vault-a",
    "key_failure_domain": "kms-security-b",
    "target_environment": "isolated-drill",
    "target_empty": True,
    "transaction_consistent": True,
    "business_invariants_passed": True,
    "expected_row_hash": "sha256:fixture-row-set",
    "restored_row_hash": "sha256:fixture-row-set",
    "retention_policy_id": "factorycare-daily-35d-v1",
    "restore_requested_at": "2026-07-24T12:04:00+00:00",
    "delete_after": "2026-08-28T12:00:00+00:00",
    "rpo_seconds": 180,
    "rpo_objective_seconds": 300,
    "rto_seconds": 420,
    "rto_objective_seconds": 600,
}


if __name__ == "__main__":
    found = audit(GOOD_RECORD)
    if found:
        raise SystemExit("\n".join(found))
    print("PASS synthetic restore record, retention, invariant oracle and RPO/RTO objectives")
    print("UNVERIFIED PostgreSQL, WAL/PITR, pg_verifybackup, real encryption/KMS, storage and production RPO/RTO")
