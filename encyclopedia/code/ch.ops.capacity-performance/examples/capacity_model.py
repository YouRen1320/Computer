"""Deterministic capacity-evidence model; this is not a network benchmark."""

from __future__ import annotations

import math
from dataclasses import dataclass
from statistics import mean
from typing import Iterable


@dataclass(frozen=True)
class WorkloadModel:
    name: str
    arrival_rate_per_second: float
    mean_service_time_ms: float
    duration_seconds: int
    warmup_seconds: int
    growth_factor: float
    burst_factor: float
    dataset_id: str
    isolated_data: bool = True

    def expected_concurrency(self) -> float:
        """Little's Law estimate L = lambda * W for a stable interval."""
        return self.arrival_rate_per_second * (self.mean_service_time_ms / 1000.0)

    def projected_peak_rate(self) -> float:
        return self.arrival_rate_per_second * self.growth_factor * self.burst_factor


@dataclass(frozen=True)
class RequestSample:
    latency_ms: float
    failed: bool
    generator_cpu_percent: float
    server_cpu_percent: float
    database_wait_ms: float
    trace_id: str
    phase: str = "steady"


@dataclass(frozen=True)
class RunEvidence:
    workload: WorkloadModel
    samples: tuple[RequestSample, ...]
    achieved_rate_per_second: float
    functional_checks_passed: bool
    query_plan_id: str


def percentile(values: Iterable[float], quantile: float) -> float:
    ordered = sorted(values)
    if not ordered:
        raise ValueError("percentile needs at least one sample")
    if not 0 < quantile <= 1:
        raise ValueError("quantile must be in (0, 1]")
    return ordered[max(0, math.ceil(quantile * len(ordered)) - 1)]


def summarize(run: RunEvidence) -> dict[str, float]:
    steady = [sample for sample in run.samples if sample.phase == "steady"]
    if not steady:
        raise ValueError("steady-state samples are required")
    latencies = [sample.latency_ms for sample in steady]
    return {
        "mean_ms": mean(latencies),
        "p50_ms": percentile(latencies, 0.50),
        "p95_ms": percentile(latencies, 0.95),
        "p99_ms": percentile(latencies, 0.99),
        "error_rate": sum(sample.failed for sample in steady) / len(steady),
        "generator_cpu_max": max(sample.generator_cpu_percent for sample in steady),
        "server_cpu_max": max(sample.server_cpu_percent for sample in steady),
        "database_wait_mean_ms": mean(sample.database_wait_ms for sample in steady),
        "trace_coverage": sum(bool(sample.trace_id) for sample in steady) / len(steady),
    }


def validate_run(run: RunEvidence, *, generator_cpu_limit: float = 70.0) -> list[str]:
    errors: list[str] = []
    if run.workload.warmup_seconds <= 0:
        errors.append("warmup interval must be declared and excluded")
    if run.workload.duration_seconds <= run.workload.warmup_seconds:
        errors.append("steady interval must remain after warmup")
    if not run.workload.isolated_data:
        errors.append("production or shared data is not an isolated performance fixture")
    if not run.samples:
        errors.append("request samples are missing")
        return errors
    summary = summarize(run)
    if summary["generator_cpu_max"] >= generator_cpu_limit:
        errors.append("load generator saturated before the system under test")
    if summary["trace_coverage"] < 0.95:
        errors.append("trace correlation is incomplete")
    if not run.functional_checks_passed:
        errors.append("functional regression checks failed")
    if not run.query_plan_id:
        errors.append("query-plan identity is missing")
    return errors


def infer_bottleneck(run: RunEvidence) -> str:
    summary = summarize(run)
    if summary["generator_cpu_max"] >= 70:
        return "invalid-run:load-generator"
    if summary["server_cpu_max"] >= 85 and summary["database_wait_mean_ms"] < 10:
        return "application-or-cpu"
    if summary["database_wait_mean_ms"] >= 30:
        return "database-wait-path"
    return "no-single-bottleneck-proven"


def compare_before_after(before: RunEvidence, after: RunEvidence) -> dict[str, float]:
    if before.workload != after.workload:
        raise ValueError("before/after workload and dataset must be identical")
    before_errors = validate_run(before)
    after_errors = validate_run(after)
    if before_errors or after_errors:
        raise ValueError(f"invalid comparison: before={before_errors}, after={after_errors}")
    left = summarize(before)
    right = summarize(after)
    if right["p95_ms"] >= left["p95_ms"]:
        raise ValueError("the proposed fix did not improve p95")
    return {
        "p95_before_ms": left["p95_ms"],
        "p95_after_ms": right["p95_ms"],
        "p95_improvement_percent": (left["p95_ms"] - right["p95_ms"]) / left["p95_ms"] * 100,
    }


def fixture_run(latencies: list[float], waits: list[float], *, plan: str) -> RunEvidence:
    workload = WorkloadModel(
        name="weekday-peak-with-growth",
        arrival_rate_per_second=40,
        mean_service_time_ms=125,
        duration_seconds=180,
        warmup_seconds=30,
        growth_factor=1.5,
        burst_factor=1.25,
        dataset_id="factorycare-synthetic-v3",
    )
    samples = tuple(
        RequestSample(
            latency_ms=value,
            failed=False,
            generator_cpu_percent=42,
            server_cpu_percent=78,
            database_wait_ms=waits[index],
            trace_id=f"trace-{index:03d}",
        )
        for index, value in enumerate(latencies)
    )
    return RunEvidence(workload, samples, achieved_rate_per_second=40, functional_checks_passed=True, query_plan_id=plan)
