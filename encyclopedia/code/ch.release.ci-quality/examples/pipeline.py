"""Deterministic CI gate model used to explain jobs, evidence, and release blocking."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class JobResult:
    name: str
    conclusion: str
    evidence: tuple[str, ...]


REQUIRED = ("java-test", "web-test", "python-test", "security", "build")


def release_decision(results: list[JobResult]) -> tuple[bool, list[str]]:
    by_name = {result.name: result for result in results}
    reasons: list[str] = []
    for name in REQUIRED:
        result = by_name.get(name)
        if result is None:
            reasons.append(f"missing required job: {name}")
        elif result.conclusion != "success":
            reasons.append(f"required job did not succeed: {name}={result.conclusion}")
        if result is not None and not result.evidence:
            reasons.append(f"job has no retained evidence: {name}")
    return not reasons, reasons
