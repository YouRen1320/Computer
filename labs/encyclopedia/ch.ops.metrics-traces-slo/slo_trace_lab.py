"""Deterministic SLO and trace drill with explicit unverified boundaries."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


FORBIDDEN_LABELS = {"user_id", "order_id", "request_id", "email", "trace_id"}
ALLOWED_LABELS = {"service", "route", "method", "status_class", "operation", "result"}


def load_fixture(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def burn(window: dict[str, int], objective: float) -> float:
    return (window["bad"] / window["total"]) / (1 - objective)


def availability(window: dict[str, int]) -> float:
    return (window["total"] - window["bad"]) / window["total"]


def latency_good_fraction(values: list[int], threshold: int) -> float:
    return sum(value <= threshold for value in values) / len(values)


def trace_findings(spans: list[dict[str, Any]]) -> list[str]:
    findings: list[str] = []
    if len({item["trace_id"] for item in spans}) != 1:
        findings.append("trace-id-discontinuity")
    span_ids = {item["span_id"] for item in spans}
    roots = 0
    for item in spans:
        parent = item["parent_span_id"]
        if parent is None:
            roots += 1
        elif parent not in span_ids:
            findings.append(f"orphan:{item['span_id']}")
    if roots != 1:
        findings.append(f"root-count:{roots}")
    return findings


def causal_span(spans: list[dict[str, Any]]) -> str:
    children = {item["parent_span_id"] for item in spans if item["parent_span_id"] is not None}
    leaves = [item for item in spans if item["span_id"] not in children]
    error_leaves = [item for item in leaves if item["status"] == "ERROR"]
    candidates = error_leaves or leaves
    return max(candidates, key=lambda item: item["duration_ms"])["name"]


def evaluate(data: dict[str, Any]) -> dict[str, Any]:
    slo = data["slo"]
    objective = slo["availability_objective"]
    alert = data["alert"]
    label_findings: list[str] = []
    for metric in data["metric_contract"]:
        labels = set(metric["labels"])
        invalid = sorted((labels & FORBIDDEN_LABELS) | (labels - ALLOWED_LABELS))
        label_findings.extend(f"{metric['name']}:{label}" for label in invalid)

    short_normal = burn(data["normal"]["short"], objective)
    long_normal = burn(data["normal"]["long"], objective)
    short_fault = burn(data["fault"]["short"], objective)
    long_fault = burn(data["fault"]["long"], objective)
    normal_alert = (short_normal >= alert["short_burn_threshold"]
                    and long_normal >= alert["long_burn_threshold"])
    fault_alert = (short_fault >= alert["short_burn_threshold"]
                   and long_fault >= alert["long_burn_threshold"])

    trace_results = []
    for trace in data["traces"]:
        findings = trace_findings(trace["spans"])
        cause = causal_span(trace["spans"])
        trace_results.append({"name": trace["name"], "findings": findings,
                              "cause": cause, "expected_cause": trace["expected_cause"]})

    normal_latency = latency_good_fraction(data["normal"]["durations_ms"], slo["latency_threshold_ms"])
    fault_latency = latency_good_fraction(data["fault"]["durations_ms"], slo["latency_threshold_ms"])
    checks = {
        "low_cardinality_labels": not label_findings,
        "normal_does_not_page": not normal_alert,
        "fault_pages": fault_alert,
        "fault_changes_availability_sli": availability(data["fault"]["long"]) < availability(data["normal"]["long"]),
        "fault_changes_latency_sli": fault_latency < normal_latency,
        "trace_continuity": all(not item["findings"] for item in trace_results),
        "trace_finds_cause": all(item["cause"] == item["expected_cause"] for item in trace_results),
        "runbook_linked": bool(alert.get("runbook")),
    }
    return {"fixture": True, "verified": all(checks.values()), "checks": checks,
            "label_findings": label_findings,
            "sli": {"normal_availability": availability(data["normal"]["long"]),
                    "fault_availability": availability(data["fault"]["long"]),
                    "normal_latency": normal_latency, "fault_latency": fault_latency},
            "burn_rate": {"normal_short": short_normal, "normal_long": long_normal,
                          "fault_short": short_fault, "fault_long": long_fault},
            "trace_results": trace_results,
            "unverified_external_boundaries": [
                "Prometheus scrape, storage, PromQL evaluation and Alertmanager delivery",
                "OpenTelemetry SDK, Collector, exporter and trace backend",
                "real asynchronous context propagation",
                "production load, fault injection, sampling and retention",
                "human runbook execution and paging noise"
            ]}


if __name__ == "__main__":
    path = Path(__file__).with_name("reliability-fixture.json")
    print(json.dumps(evaluate(load_fixture(path)), ensure_ascii=False, sort_keys=True))
