"""Small, deterministic helpers for traceable system-design evidence."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class CapacityAssumptions:
    organizations: int
    technicians_per_organization: int
    requests_per_technician_per_day: int
    peak_factor: float
    active_seconds_per_day: int
    request_bytes: int
    response_bytes: int
    records_per_day: int
    record_bytes: int
    retention_days: int

    def daily_requests(self) -> int:
        return self.organizations * self.technicians_per_organization * self.requests_per_technician_per_day

    def peak_requests_per_second(self) -> float:
        return self.daily_requests() / self.active_seconds_per_day * self.peak_factor

    def peak_bytes_per_second(self) -> float:
        return self.peak_requests_per_second() * (self.request_bytes + self.response_bytes)

    def retained_bytes(self) -> int:
        return self.records_per_day * self.record_bytes * self.retention_days


def audit_traceability(packet: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    requirements = {item["id"] for item in packet.get("requirements", [])}
    for component in packet.get("components", []):
        traces = set(component.get("requirement_ids", []))
        if not traces:
            errors.append(f"component {component.get('id')} is technology-first and untraced")
        if traces - requirements:
            errors.append(f"component {component.get('id')} references unknown requirements")
    for mode in packet.get("failure_modes", []):
        for field in ("detect", "mitigate", "recover"):
            if not mode.get(field):
                errors.append(f"failure mode {mode.get('id')} lacks {field}")
    adr = packet.get("adr", {})
    if not adr.get("rejected_options") or not adr.get("evolution_triggers"):
        errors.append("ADR lacks rejected options or measurable evolution triggers")
    return errors


SAMPLE = CapacityAssumptions(
    organizations=120,
    technicians_per_organization=25,
    requests_per_technician_per_day=80,
    peak_factor=6.0,
    active_seconds_per_day=36_000,
    request_bytes=1_200,
    response_bytes=2_800,
    records_per_day=60_000,
    record_bytes=1_500,
    retention_days=365,
)
