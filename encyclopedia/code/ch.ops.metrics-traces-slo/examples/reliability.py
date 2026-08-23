"""Small deterministic model for metric, trace, SLI/SLO and alert contracts."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Literal


FORBIDDEN_LABELS = {"user_id", "order_id", "request_id", "email", "trace_id"}
ALLOWED_LABELS = {"service", "route", "method", "status_class", "operation", "result"}


@dataclass(frozen=True)
class RatioResult:
    state: Literal["value", "zero-traffic", "telemetry-missing"]
    value: float | None


@dataclass(frozen=True)
class AlertDecision:
    state: Literal["page", "within-budget", "pending-no-traffic", "telemetry-alert"]
    page: bool


def audit_labels(labels: set[str]) -> list[str]:
    return sorted((labels & FORBIDDEN_LABELS) | (labels - ALLOWED_LABELS))


def _event_counts(total: int | None, bad: int | None) -> RatioResult | tuple[int, int]:
    """Validate every event ratio through one explicit no-data boundary."""
    if total is None or bad is None:
        return RatioResult("telemetry-missing", None)
    if total < 0 or bad < 0 or bad > total:
        raise ValueError("invalid event counts")
    if total == 0:
        return RatioResult("zero-traffic", None)
    return total, bad


def availability_sli(total: int | None, bad: int | None) -> RatioResult:
    counts = _event_counts(total, bad)
    if isinstance(counts, RatioResult):
        return counts
    checked_total, checked_bad = counts
    return RatioResult("value", (checked_total - checked_bad) / checked_total)


def latency_sli(durations_ms: list[int], threshold_ms: int) -> float:
    if not durations_ms:
        raise ValueError("at least one duration is required")
    return sum(value <= threshold_ms for value in durations_ms) / len(durations_ms)


def burn_rate(total: int | None, bad: int | None, objective: float) -> RatioResult:
    if not 0 < objective < 1:
        raise ValueError("objective must be between zero and one")
    counts = _event_counts(total, bad)
    if isinstance(counts, RatioResult):
        return counts
    checked_total, checked_bad = counts
    return RatioResult("value", (checked_bad / checked_total) / (1 - objective))


def multi_window_alert(short: dict[str, int | None], long: dict[str, int | None], objective: float,
                       *, short_threshold: float, long_threshold: float) -> AlertDecision:
    short_rate = burn_rate(short.get("total"), short.get("bad"), objective)
    long_rate = burn_rate(long.get("total"), long.get("bad"), objective)
    states = {short_rate.state, long_rate.state}
    if "telemetry-missing" in states:
        return AlertDecision("telemetry-alert", False)
    if "zero-traffic" in states:
        return AlertDecision("pending-no-traffic", False)
    assert short_rate.value is not None and long_rate.value is not None
    page = short_rate.value >= short_threshold and long_rate.value >= long_threshold
    return AlertDecision("page" if page else "within-budget", page)


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
