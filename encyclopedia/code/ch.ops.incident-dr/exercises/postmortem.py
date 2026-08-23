"""Public red exercise: turn vague promises into verifiable corrective actions."""


def corrective_actions() -> list[dict[str, str]]:
    # Deliberately incomplete: this is a slogan, not an engineering action.
    return [{"id": "CA-1", "acceptance": "加强监控"}]


def audit(actions: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    if len(actions) < 3:
        errors.append("at least three actions required")
    for action in actions:
        for field in ("owner", "due_at", "acceptance", "verification_command", "regression_test"):
            if not action.get(field):
                errors.append(f"{action.get('id', '<unknown>')} lacks {field}")
    return errors
