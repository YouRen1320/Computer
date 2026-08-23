"""Deterministic supply-chain drill; no external scanner or secret manager is used."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def load_fixture(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def evaluate(data: dict[str, Any]) -> dict[str, Any]:
    cfg = data["config"]
    allowed = set(cfg["allowed"])
    merged: dict[str, str] = {}
    unknown: list[str] = []
    for source in ("defaults", "environment"):
        values = cfg[source]
        unknown.extend(sorted(set(values) - allowed))
        merged.update({key: value for key, value in values.items() if key in allowed})
    missing = sorted(set(cfg["required"]) - set(merged))

    surface_findings = [item["surface"] for item in data["surface_reports"]
                        if item["secret_marker_present"]]
    components = {item["name"]: item["version"] for item in data["sbom"]["components"]}
    component_fields_complete = all(item.get("purl") and item.get("hashes")
                                    for item in data["sbom"]["components"])
    rotation = data["rotation"]
    rotation_ok = (not rotation["old_valid_after_cutover"]
                   and rotation["new_valid_after_cutover"])
    release = data["release_manifest"]
    manifest_ok = all(release.get(key) for key in
                      ("artifact_digest", "sbom_path", "sbom_digest", "provenance_path"))

    decisions: dict[str, str] = {}
    for finding in data["vulnerabilities"]:
        if finding["reachable"] and finding["known_exploited"]:
            decisions[finding["id"]] = "block-release"
        elif finding["reachable"] and finding["severity"] in {"HIGH", "CRITICAL"}:
            decisions[finding["id"]] = "remediate-before-release"
        else:
            decisions[finding["id"]] = "document-and-monitor"

    checks = {
        "config_schema": not unknown and not missing,
        "secret_surfaces_clean": not surface_findings,
        "rotation_cutover": rotation_ok,
        "sbom_matches_lock": components == data["lock"] and component_fields_complete,
        "manifest_links_evidence": manifest_ok,
        "risk_based_triage": decisions.get("ADV-DEMO-001") == "block-release"
                             and decisions.get("ADV-DEMO-002") == "document-and-monitor",
    }
    return {
        "fixture": True,
        "verified": all(checks.values()),
        "checks": checks,
        "resolved_config": merged,
        "secret_reference": data["secret_reference"],
        "surface_findings": surface_findings,
        "triage": decisions,
        "unverified_external_boundaries": [
            "real secret manager and credential revocation",
            "Git history, image-layer, and CI-log scanners",
            "SBOM generator/schema validator/signature verifier",
            "registry attestation and production deployment"
        ],
    }


if __name__ == "__main__":
    fixture = Path(__file__).with_name("release-fixture.json")
    print(json.dumps(evaluate(load_fixture(fixture)), ensure_ascii=False, sort_keys=True))
