"""Validate a synthetic system-design packet for the Nanchang field-service scenario."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def capacity(packet: dict[str, Any]) -> dict[str, float]:
    assumptions = packet["capacity_assumptions"]
    daily = (
        assumptions["organizations"]
        * assumptions["technicians_per_organization"]
        * assumptions["requests_per_technician_per_day"]
    )
    peak_rps = daily / assumptions["active_seconds_per_day"] * assumptions["peak_factor"]
    traffic_bytes_per_second = peak_rps * (
        assumptions["request_bytes"] + assumptions["response_bytes"]
    )
    retained_bytes = (
        assumptions["records_per_day"]
        * assumptions["record_bytes"]
        * assumptions["retention_days"]
        * assumptions["replication_copies"]
    )
    return {
        "daily_requests": daily,
        "peak_requests_per_second": peak_rps,
        "traffic_bytes_per_second": traffic_bytes_per_second,
        "retained_bytes_including_replication": retained_bytes,
    }


def audit(packet: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    manifest = packet.get("manifest", {})
    if manifest.get("evidence_kind") != "synthetic-design-review":
        errors.append("manifest must label evidence synthetic-design-review")
    if manifest.get("real_load_test_verified") is not False:
        errors.append("fixture must not claim a real load test")
    if manifest.get("production_metrics_used") is not False:
        errors.append("fixture must not claim production metrics")

    requirements = packet.get("requirements", [])
    requirement_ids = {item.get("id") for item in requirements}
    if not any(item.get("kind") == "functional" for item in requirements):
        errors.append("functional requirement is missing")
    if not any(item.get("kind") == "quality-attribute" for item in requirements):
        errors.append("quality attribute is missing")

    context_actors = set(packet.get("system_context", {}).get("actors", []))
    if not {"technician", "dispatcher", "tenant-admin"}.issubset(context_actors):
        errors.append("system context omits a primary actor")

    for flow in packet.get("data_flows", []):
        if not flow.get("business_authority") == "java-api-postgresql":
            errors.append(f"flow {flow.get('id')} violates Java business authority")
        if flow.get("python_ai_data") not in {"none", "rebuildable-derived"}:
            errors.append(f"flow {flow.get('id')} gives Python/AI durable business authority")

    for component in packet.get("components", []):
        traces = set(component.get("requirement_ids", []))
        if not traces:
            errors.append(f"component {component.get('id')} has no requirement trace")
        if traces - requirement_ids:
            errors.append(f"component {component.get('id')} references an unknown requirement")

    assumptions = packet.get("capacity_assumptions", {})
    required_units = {
        "organizations": "count",
        "technicians_per_organization": "count/org",
        "requests_per_technician_per_day": "request/technician/day",
        "active_seconds_per_day": "second/day",
        "peak_factor": "ratio",
        "request_bytes": "byte/request",
        "response_bytes": "byte/request",
        "records_per_day": "record/day",
        "record_bytes": "byte/record",
        "retention_days": "day",
        "replication_copies": "copy",
    }
    units = packet.get("capacity_units", {})
    for name, unit in required_units.items():
        if name not in assumptions:
            errors.append(f"capacity assumption missing: {name}")
        if units.get(name) != unit:
            errors.append(f"capacity unit mismatch for {name}: expected {unit}")
    if not errors:
        calculated = capacity(packet)
        for name, expected in packet.get("capacity_results", {}).items():
            if abs(calculated.get(name, float("nan")) - expected) > 1e-9:
                errors.append(f"capacity result cannot be reproduced: {name}")

    failure_modes = packet.get("failure_modes", [])
    if len(failure_modes) < 3:
        errors.append("at least three failure modes are required")
    for mode in failure_modes:
        for field in ("detect", "mitigate", "recover", "residual_risk"):
            if not mode.get(field):
                errors.append(f"failure mode {mode.get('id')} lacks {field}")

    slos = packet.get("slos", [])
    for slo in slos:
        for field in ("indicator", "objective", "window", "error_budget_policy"):
            if not slo.get(field):
                errors.append(f"SLO {slo.get('id')} lacks {field}")

    adr = packet.get("adr", {})
    for field in ("decision", "consequences", "rejected_options", "evolution_triggers", "rollback"):
        if not adr.get(field):
            errors.append(f"ADR lacks {field}")
    if "microservices" in adr.get("decision", "").lower() and not adr.get("requirement_ids"):
        errors.append("microservices were selected before requirements")
    return errors


def load_packet() -> dict[str, Any]:
    return json.loads(Path(__file__).with_name("design_packet.json").read_text(encoding="utf-8"))


if __name__ == "__main__":
    design = load_packet()
    problems = audit(design)
    if problems:
        raise SystemExit("\n".join(problems))
    print("PASS assumptions, context, traceability, capacity, failure modes, SLO and ADR gates")
    print(json.dumps(capacity(design), ensure_ascii=False, sort_keys=True))
    print("UNVERIFIED real users, production traffic, database plans, host sizing, network throughput and live failure behavior")
