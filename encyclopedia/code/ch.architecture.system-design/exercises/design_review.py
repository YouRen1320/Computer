"""Public red exercise: repair technology-first and unitless design claims."""


def design_packet() -> dict:
    return {
        "requirements": [{"id": "FR-1", "text": "update work order"}],
        "components": [{"id": "microservices-and-kafka", "requirement_ids": []}],
        "capacity": {"storage": 500, "unit": "MB-or-MiB"},
        "failure_modes": [{"id": "db-down", "detect": "alert", "mitigate": "", "recover": ""}],
        "adr": {"rejected_options": [], "evolution_triggers": []},
    }


def audit(packet: dict) -> list[str]:
    errors: list[str] = []
    known = {item["id"] for item in packet["requirements"]}
    for component in packet["components"]:
        traces = set(component.get("requirement_ids", []))
        if not traces or traces - known:
            errors.append("component is not traceable to a requirement")
    if packet["capacity"].get("unit") not in {"byte", "MB-decimal", "MiB-binary"}:
        errors.append("capacity unit is ambiguous")
    for mode in packet["failure_modes"]:
        if not all(mode.get(field) for field in ("detect", "mitigate", "recover")):
            errors.append("failure mode omits detection, mitigation or recovery")
    if not packet["adr"].get("rejected_options") or not packet["adr"].get("evolution_triggers"):
        errors.append("ADR omits rejected options or evolution triggers")
    return errors
