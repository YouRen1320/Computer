"""In-memory expand/contract and canary model for teaching deployment gates."""

from __future__ import annotations

import re
from dataclasses import dataclass, field


DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")


@dataclass
class SchemaFixture:
    columns: set[str] = field(default_factory=lambda: {"id", "assignee_name"})
    rows: dict[int, dict[str, str | int | None]] = field(default_factory=dict)


@dataclass(frozen=True)
class CanaryEvidence:
    artifact_digest: str
    ready_replicas: int
    desired_replicas: int
    error_rate: float
    p95_ms: float
    migration_state: str


@dataclass(frozen=True)
class ContractEvidence:
    old_replica_count: int
    legacy_read_count: int
    backfill_complete: bool
    mixed_version_contract_green: bool
    backup_restore_drill_green: bool
    canary_green: bool
    migration_state: str


def expand(schema: SchemaFixture) -> None:
    if "assignee_name" not in schema.columns:
        raise ValueError("legacy column is missing before expand")
    schema.columns.add("assignee_display_name")
    for row in schema.rows.values():
        row.setdefault("assignee_display_name", None)


def write_v1(schema: SchemaFixture, work_order_id: int, value: str) -> None:
    if "assignee_name" not in schema.columns:
        raise ValueError("v1 cannot write after legacy column contract")
    row = schema.rows.setdefault(work_order_id, {"id": work_order_id})
    row["assignee_name"] = value
    if "assignee_display_name" in schema.columns:
        row.setdefault("assignee_display_name", None)


def write_v2(schema: SchemaFixture, work_order_id: int, value: str) -> None:
    if not {"assignee_name", "assignee_display_name"}.issubset(schema.columns):
        raise ValueError("v2 requires expanded backward-compatible schema")
    row = schema.rows.setdefault(work_order_id, {"id": work_order_id})
    # During coexistence v2 dual-writes so v1 and v2 observe the same fact.
    row["assignee_name"] = value
    row["assignee_display_name"] = value


def read_v2(schema: SchemaFixture, work_order_id: int) -> str:
    row = schema.rows[work_order_id]
    value = row.get("assignee_display_name") or row.get("assignee_name")
    if not isinstance(value, str):
        raise ValueError("assignee value is absent")
    return value


def backfill_batch(
    schema: SchemaFixture,
    *,
    checkpoint: int,
    batch_size: int,
    fail_on_id: int | None = None,
) -> tuple[int, bool]:
    if "assignee_display_name" not in schema.columns:
        raise ValueError("expand must run before backfill")
    candidates = [row_id for row_id in sorted(schema.rows) if row_id > checkpoint][:batch_size]
    current = checkpoint
    for row_id in candidates:
        if row_id == fail_on_id:
            return current, False
        row = schema.rows[row_id]
        if row.get("assignee_display_name") is None:
            row["assignee_display_name"] = row.get("assignee_name")
        current = row_id
    complete = not any(row_id > current for row_id in schema.rows)
    return current, complete


def canary_decision(evidence: CanaryEvidence, *, max_error_rate: float, max_p95_ms: float) -> str:
    if not DIGEST.fullmatch(evidence.artifact_digest):
        return "rollback:mutable-artifact"
    if evidence.migration_state != "success":
        return "rollback:migration-not-green"
    if evidence.ready_replicas != evidence.desired_replicas:
        return "rollback:not-ready"
    if evidence.error_rate > max_error_rate:
        return "rollback:error-rate"
    if evidence.p95_ms > max_p95_ms:
        return "rollback:latency"
    return "promote"


def contract_ready(schema: SchemaFixture, evidence: ContractEvidence) -> bool:
    data_complete = all(row.get("assignee_display_name") is not None for row in schema.rows.values())
    return all(
        (
            "assignee_display_name" in schema.columns,
            evidence.old_replica_count == 0,
            evidence.legacy_read_count == 0,
            evidence.backfill_complete,
            data_complete,
            evidence.mixed_version_contract_green,
            evidence.backup_restore_drill_green,
            evidence.canary_green,
            evidence.migration_state == "success",
        )
    )


def contract(schema: SchemaFixture, evidence: ContractEvidence) -> None:
    if not contract_ready(schema, evidence):
        raise ValueError("contract gate is not satisfied")
    schema.columns.remove("assignee_name")
    for row in schema.rows.values():
        row.pop("assignee_name", None)


def application_rollback_supported(schema: SchemaFixture) -> bool:
    """Old application can return only while its legacy contract still exists."""
    return "assignee_name" in schema.columns
