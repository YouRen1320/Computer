"""Audit a deterministic Nginx/Java/PostgreSQL telemetry fixture."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


BANNED_KEYS = {"authorization", "token", "password", "secret", "email", "phone", "request_body", "response_body"}
REQUIRED_LOG_KEYS = {"timestamp", "severity", "service", "event", "correlation_id", "trace_id", "span_id", "attributes"}


def load_fixture(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def health_state(scenario: dict[str, Any]) -> dict[str, Any]:
    live = scenario["process_ok"]
    ready = live and scenario["startup_complete"] and scenario["postgres_ok"]
    if not live:
        state = "DOWN"
    elif not scenario["startup_complete"]:
        state = "STARTING"
    elif not scenario["postgres_ok"]:
        state = "NOT_READY"
    elif not scenario["optional_provider_ok"]:
        state = "DEGRADED"
    else:
        state = "UP"
    return {"state": state, "live": live, "ready": ready,
            "liveness_http": 200 if live else 503,
            "readiness_http": 200 if ready else 503}


def nested_keys(value: Any) -> set[str]:
    if isinstance(value, dict):
        return set(value) | set().union(*(nested_keys(item) for item in value.values()), set())
    if isinstance(value, list):
        return set().union(*(nested_keys(item) for item in value), set())
    return set()


def audit(data: dict[str, Any]) -> dict[str, Any]:
    logs = data["logs"]
    schema_findings = [index for index, record in enumerate(logs)
                       if set(record) != REQUIRED_LOG_KEYS]
    sensitive_findings = [index for index, record in enumerate(logs)
                          if nested_keys(record) & BANNED_KEYS]
    correlation_ids = {record["correlation_id"] for record in logs}
    trace_ids = {record["trace_id"] for record in logs}
    services = {record["service"] for record in logs}
    health_findings = [scenario["name"] for scenario in data["health_scenarios"]
                       if health_state(scenario) != scenario["expected"]]
    checks = {
        "log_schema": not schema_findings,
        "log_redaction": not sensitive_findings,
        "correlation_continuity": correlation_ids == {data["request"]["correlation_id"]},
        "trace_continuity": trace_ids == {data["request"]["trace_id"]},
        "all_layers_visible": services == {"nginx", "java-api", "postgresql"},
        "health_matrix": not health_findings,
    }
    return {"fixture": True, "verified": all(checks.values()), "checks": checks,
            "schema_findings": schema_findings,
            "sensitive_findings": sensitive_findings,
            "health_findings": health_findings,
            "unverified_external_boundaries": [
                "real Nginx header forwarding",
                "Java logging framework and OpenTelemetry SDK instrumentation",
                "PostgreSQL driver telemetry",
                "container orchestrator probe and restart behavior",
                "production log storage, retention, access control and deletion"
            ]}


if __name__ == "__main__":
    path = Path(__file__).with_name("telemetry-fixture.json")
    print(json.dumps(audit(load_fixture(path)), ensure_ascii=False, sort_keys=True))
