"""Claim-ledger oracle for a controlled bilingual portfolio fixture."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).parent
LEVELS = {"verified-local", "reviewed", "unverified-external", "superseded"}


def audit(document: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    ids: set[str] = set()
    for index, claim in enumerate(document.get("claims", [])):
        prefix = f"claims[{index}]"
        claim_id = claim.get("id")
        if not claim_id or claim_id in ids:
            errors.append(f"{prefix}.id is missing or duplicated")
        ids.add(str(claim_id))
        for field in ("text_zh", "text_en", "project_kind", "ownership", "evidence", "verification_level"):
            if not claim.get(field):
                errors.append(f"{prefix}.{field} is required")
        if claim.get("verification_level") not in LEVELS:
            errors.append(f"{prefix}.verification_level is invalid")
        if claim.get("production") and claim.get("verification_level") != "reviewed":
            errors.append(f"{prefix} escalates non-reviewed evidence to production")
        if claim.get("ai_assisted") and not claim.get("human_verification"):
            errors.append(f"{prefix} hides the missing human verification of AI work")
        if claim.get("project_kind") == "employment" and not claim.get("verifiable_dates"):
            errors.append(f"{prefix} employment dates are not verifiable")
        for uri in claim.get("evidence", []):
            if not str(uri).startswith("fixture://"):
                errors.append(f"{prefix} uses a non-fixture URI in this controlled lab")
    if not document.get("claims"):
        errors.append("at least one claim is required")
    return errors


if __name__ == "__main__":
    fixture = json.loads((ROOT / "claims.fixture.json").read_text(encoding="utf-8"))
    found = audit(fixture)
    if found:
        raise SystemExit("\n".join(found))
    print("PASS controlled bilingual claim-evidence ledger")
    print("UNVERIFIED real Git links, reviewers, interview performance, background checks, JDs and hiring outcomes")
