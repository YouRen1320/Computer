"""Audit a synthetic performance-run record and classify invalid evidence."""

from __future__ import annotations

from typing import Any


def audit(record: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if record.get("warmup_seconds", 0) <= 0 or not record.get("warmup_excluded"):
        errors.append("warmup is absent or included in measured interval")
    if record.get("generator_cpu_max", 100) >= 70:
        errors.append("client generator is saturated")
    for name in ("p50_ms", "p95_ms", "p99_ms"):
        if name not in record:
            errors.append(f"tail-latency evidence missing: {name}")
    if record.get("dataset_environment") == "production" or not record.get("dataset_isolated"):
        errors.append("test data is not isolated from production")
    if record.get("before_workload_id") != record.get("after_workload_id"):
        errors.append("before/after workloads differ")
    if record.get("before_dataset_id") != record.get("after_dataset_id"):
        errors.append("before/after datasets differ")
    if not record.get("functional_regression_passed"):
        errors.append("optimization lacks a green functional regression")
    if not record.get("resource_metrics_correlated") or not record.get("trace_correlated"):
        errors.append("latency is not correlated with resource metrics and traces")
    return errors


GOOD_RECORD = {
    "warmup_seconds": 30,
    "warmup_excluded": True,
    "generator_cpu_max": 43,
    "p50_ms": 65,
    "p95_ms": 130,
    "p99_ms": 180,
    "dataset_environment": "isolated-test",
    "dataset_isolated": True,
    "before_workload_id": "weekday-peak-v3",
    "after_workload_id": "weekday-peak-v3",
    "before_dataset_id": "factorycare-synthetic-v3",
    "after_dataset_id": "factorycare-synthetic-v3",
    "functional_regression_passed": True,
    "resource_metrics_correlated": True,
    "trace_correlated": True,
}


if __name__ == "__main__":
    problems = audit(GOOD_RECORD)
    if problems:
        raise SystemExit("\n".join(problems))
    print("PASS synthetic workload/evidence gate and before-after comparison contract")
    print("UNVERIFIED HTTP load, PostgreSQL plans, containers, k6, OpenTelemetry and real capacity")
