"""Audit truthful, evidence-backed portfolio claims."""

from __future__ import annotations

from typing import Any


ALLOWED_LEVELS = {"verified-local", "reviewed", "unverified-external", "superseded"}


def audit_claim(claim: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for field in ("text", "project_kind", "ownership", "evidence", "verification_level"):
        if not claim.get(field):
            errors.append(f"missing {field}")
    if claim.get("verification_level") not in ALLOWED_LEVELS:
        errors.append("verification_level is unsupported")
    if claim.get("project_kind") == "employment" and not claim.get("verifiable_dates"):
        errors.append("employment claims require verifiable dates")
    if claim.get("ai_assisted") and not claim.get("human_verification"):
        errors.append("AI-assisted work requires a human verification record")
    if claim.get("production") and claim.get("verification_level") != "reviewed":
        errors.append("production cannot be inferred from local evidence")
    return errors
