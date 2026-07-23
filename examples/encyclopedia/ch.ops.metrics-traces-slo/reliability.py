"""Small deterministic model for metric, trace, SLI/SLO and alert contracts."""
from __future__ import annotations

from typing import Any


FORBIDDEN_LABELS = {"user_id", "order_id", "request_id", "email", "trace_id"}
ALLOWED_LABELS = {"service", "route", "method", "status_class", "operation", "result"}


def audit_labels(labels: set[str]) -> list[str]:
    return sorted((labels & FORBIDDEN_LABELS) | (labels - ALLOWED_LABELS))


def availability_sli(total: int, bad: int) -> float:
    if total <= 0 or not 0 <= bad <= total:
        raise ValueError("invalid event counts")
    return (total - bad) / total


def latency_sli(durations_ms: list[int], threshold_ms: int) -> float:
    if not durations_ms:
        raise ValueError("at least one duration is required")
    return sum(value <= threshold_ms for value in durations_ms) / len(durations_ms)


def burn_rate(total: int, bad: int, objective: float) -> float:
    if not 0 < objective < 1:
        raise ValueError("objective must be between zero and one")
    return (bad / total) / (1 - objective)


def multi_window_alert(short: dict[str, int], long: dict[str, int], objective: float,
                       *, short_threshold: float, long_threshold: float) -> bool:
    return (burn_rate(short["total"], short["bad"], objective) >= short_threshold
            and burn_rate(long["total"], long["bad"], objective) >= long_threshold)


def trace_findings(spans: list[dict[str, Any]]) -> list[str]:
    findings: list[str] = []
    trace_ids = {span["trace_id"] for span in spans}
    if len(trace_ids) != 1:
        findings.append("trace-id-discontinuity")
    ids = {span["span_id"] for span in spans}
    for span in spans:
        parent = span.get("parent_span_id")
        if parent is not None and parent not in ids:
            findings.append(f"orphan-span:{span['span_id']}")
    return findings


if __name__ == "__main__":
    print({"availability": availability_sli(1000, 2),
           "latency": latency_sli([80, 110, 240, 700], 300),
           "burn_rate": burn_rate(1000, 20, 0.99)})
