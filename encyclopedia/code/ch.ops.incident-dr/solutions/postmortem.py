"""Private reference solution for verifiable corrective actions."""


def corrective_actions() -> list[dict[str, str]]:
    return [
        {"id": "CA-1", "owner": "db-team", "due_at": "2026-08-01", "acceptance": "restore rehearsal <=25m", "verification_command": "./restore-drill.sh", "regression_test": "quarterly-restore"},
        {"id": "CA-2", "owner": "release-team", "due_at": "2026-08-03", "acceptance": "bad artifact is blocked", "verification_command": "./artifact-gate.sh", "regression_test": "promotion-gate"},
        {"id": "CA-3", "owner": "sre-team", "due_at": "2026-08-05", "acceptance": "page contains runbook", "verification_command": "./alert-contract.sh", "regression_test": "alert-routing"},
    ]


def audit(actions: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    if len(actions) < 3:
        errors.append("at least three actions required")
    for action in actions:
        for field in ("owner", "due_at", "acceptance", "verification_command", "regression_test"):
            if not action.get(field):
                errors.append(f"{action.get('id', '<unknown>')} lacks {field}")
    return errors
