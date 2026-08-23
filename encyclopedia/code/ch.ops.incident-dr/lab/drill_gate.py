"""Audit a synthetic database-outage plus bad-release tabletop packet."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any


def instant(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("timestamp must include timezone")
    return parsed


def minutes_between(start: str, end: str) -> float:
    return (instant(end) - instant(start)).total_seconds() / 60


def audit(packet: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    manifest = packet.get("manifest", {})
    if manifest.get("evidence_kind") != "synthetic-tabletop":
        errors.append("evidence kind must be synthetic-tabletop")
    for field in ("live_drill_verified", "real_rto_rpo_verified", "commands_executed"):
        if manifest.get(field) is not False:
            errors.append(f"{field} must remain false for this fixture")
    if not manifest.get("artifact_identity"):
        errors.append("artifact identity is missing")

    required_roles = {"incident_commander", "operations", "communications", "scribe"}
    roles = packet.get("roles", {})
    if required_roles - set(roles):
        errors.append("incident command roles are incomplete")
    if len(set(roles.values())) < 3:
        errors.append("one person cannot silently occupy every command role")

    timeline = packet.get("timeline", [])
    if not timeline:
        errors.append("timeline is missing")
        return errors
    times = [instant(event["at"]) for event in timeline]
    if times != sorted(times):
        errors.append("timeline is not chronological")
    if any(not event.get("evidence_ids") for event in timeline):
        errors.append("every timeline event needs immutable evidence references")

    checkpoint_index = next((i for i, event in enumerate(timeline) if event["kind"] == "checkpoint"), None)
    recovery_index = next((i for i, event in enumerate(timeline) if event["kind"] == "recovery_started"), None)
    if checkpoint_index is None or recovery_index is None or checkpoint_index >= recovery_index:
        errors.append("a preserved checkpoint must precede recovery")

    recovery = packet.get("recovery", {})
    if not recovery.get("authorized_by"):
        errors.append("recovery lacks explicit authorization")
    if recovery.get("overwrites_source"):
        errors.append("recovery must not overwrite the only source copy")
    rto_actual = minutes_between(recovery["declared_at"], recovery["service_restored_at"])
    rpo_actual = minutes_between(recovery["latest_recoverable_at"], recovery["failure_at"])
    if rto_actual > recovery.get("rto_target_minutes", -1):
        errors.append("synthetic RTO target missed")
    if rpo_actual > recovery.get("rpo_target_minutes", -1):
        errors.append("synthetic RPO target missed")

    communications = packet.get("communications", [])
    communication_times = [instant(item["at"]) for item in communications]
    if len(communication_times) < 2:
        errors.append("communication cadence has fewer than two updates")
    elif any((right - left).total_seconds() > 15 * 60 for left, right in zip(communication_times, communication_times[1:])):
        errors.append("communication cadence exceeds 15 minutes")

    actions = packet.get("corrective_actions", [])
    if len(actions) < 3:
        errors.append("three corrective actions are required")
    for action in actions:
        for field in ("owner", "due_at", "acceptance", "verification_command", "regression_test"):
            if not action.get(field):
                errors.append(f"action {action.get('id', '<unknown>')} lacks {field}")
    postmortem = packet.get("postmortem", {})
    if postmortem.get("blames_person"):
        errors.append("postmortem assigns personal blame instead of examining system conditions")
    return errors


def load_packet() -> dict[str, Any]:
    return json.loads(Path(__file__).with_name("drill.json").read_text(encoding="utf-8"))


if __name__ == "__main__":
    problems = audit(load_packet())
    if problems:
        raise SystemExit("\n".join(problems))
    print("PASS synthetic incident command, timeline, recovery-decision and corrective-action gates")
    print("UNVERIFIED live PostgreSQL restore/failover, Docker/Compose/Nginx/Ubuntu commands, real RTO/RPO and real user impact")
