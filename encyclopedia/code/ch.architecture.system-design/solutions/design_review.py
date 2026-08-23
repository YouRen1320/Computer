"""Private reference solution for a traceable, unit-explicit design record."""


def design_packet() -> dict:
    return {
        "requirements": [{"id": "FR-1", "text": "update work order"}, {"id": "QA-1", "text": "auditable tenant isolation"}],
        "components": [{"id": "java-modular-monolith", "requirement_ids": ["FR-1", "QA-1"]}],
        "capacity": {"storage": 524_288_000, "unit": "byte"},
        "failure_modes": [{"id": "db-down", "detect": "write SLI and probe", "mitigate": "fail writes explicitly", "recover": "approved restore runbook"}],
        "adr": {"rejected_options": ["microservices before independent scaling evidence"], "evolution_triggers": ["module needs measured 10x independent scaling"]},
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
