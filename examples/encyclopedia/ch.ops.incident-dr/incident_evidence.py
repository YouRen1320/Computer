"""Validate a deterministic incident record without claiming a live recovery drill."""

from __future__ import annotations

from datetime import datetime
from typing import Any


REQUIRED_ROLES = {"incident_commander", "operations", "communications", "scribe"}


def instant(value: str) -> datetime:
    """Parse an explicit ISO-8601 timestamp and reject local-time ambiguity."""
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("timestamp must include an offset or Z")
    return parsed


def audit_incident(record: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if record.get("evidence_kind") != "synthetic-tabletop":
        errors.append("example must identify itself as synthetic-tabletop evidence")
    if record.get("real_rto_rpo_verified") is not False:
        errors.append("example must not claim real RTO/RPO verification")

    roles = record.get("roles", {})
    missing_roles = REQUIRED_ROLES - set(roles)
    if missing_roles:
        errors.append(f"incident roles missing: {sorted(missing_roles)}")
    if any(not owner for owner in roles.values()):
        errors.append("each incident role needs a named owner")

    timeline = record.get("timeline", [])
    if not timeline:
        errors.append("timeline is empty")
    else:
        timestamps = [instant(event["at"]) for event in timeline]
        if timestamps != sorted(timestamps):
            errors.append("timeline is not chronological")
        for event in timeline:
            if not event.get("evidence_ids"):
                errors.append(f"timeline event lacks evidence: {event.get('kind', '<unknown>')}")

    actions = record.get("corrective_actions", [])
    if len(actions) < 3:
        errors.append("at least three corrective actions are required")
    for action in actions:
        for field in ("owner", "due_at", "acceptance", "regression_test"):
            if not action.get(field):
                errors.append(f"corrective action {action.get('id', '<unknown>')} lacks {field}")
    return errors


GOOD_RECORD = {
    "evidence_kind": "synthetic-tabletop",
    "real_rto_rpo_verified": False,
    "severity": "SEV-1",
    "roles": {
        "incident_commander": "oncall-a",
        "operations": "db-oncall",
        "communications": "support-lead",
        "scribe": "engineer-b",
    },
    "timeline": [
        {"at": "2026-07-24T10:00:00+08:00", "kind": "declared", "evidence_ids": ["alert-17"]},
        {"at": "2026-07-24T10:04:00+08:00", "kind": "checkpoint", "evidence_ids": ["snapshot-42"]},
        {"at": "2026-07-24T10:16:00+08:00", "kind": "recovery", "evidence_ids": ["restore-log-9"]},
    ],
    "corrective_actions": [
        {"id": "CA-1", "owner": "db-team", "due_at": "2026-08-01", "acceptance": "restore rehearsal passes", "regression_test": "drill-restore"},
        {"id": "CA-2", "owner": "release-team", "due_at": "2026-08-03", "acceptance": "bad artifact is blocked", "regression_test": "artifact-gate"},
        {"id": "CA-3", "owner": "sre-team", "due_at": "2026-08-05", "acceptance": "page includes runbook", "regression_test": "alert-route"},
    ],
}
