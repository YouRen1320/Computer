"""Dry-run promotion oracle for a synthetic release manifest."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).parent
DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")


def verify(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    commit = str(data.get("commit", ""))
    if not COMMIT.fullmatch(commit):
        errors.append("full commit identity is required")
    gates = data.get("quality_gates", {})
    if not gates or any(value != "success" for value in gates.values()):
        errors.append("quality gates are incomplete or failed")
    artifacts = data.get("artifacts", {})
    for name, record in artifacts.items():
        for field in ("digest", "sbom_digest"):
            if not DIGEST.fullmatch(str(record.get(field, ""))):
                errors.append(f"{name}.{field} is not a sha256 identity")
        if not record.get("provenance_uri"):
            errors.append(f"{name}.provenance_uri is missing")
    environments = data.get("environments", {})
    for environment, resolved in environments.items():
        for name, record in artifacts.items():
            if resolved.get(name) != record.get("digest"):
                errors.append(f"{environment} resolved a different {name} artifact")
    smoke = data.get("smoke", {})
    for check in ("tls", "static", "api"):
        if smoke.get(check) != "pass":
            errors.append(f"proxy smoke failed or missing: {check}")
    if smoke.get("reported_commit") != commit:
        errors.append("API smoke reached a different commit")
    return errors


if __name__ == "__main__":
    manifest = json.loads((ROOT / "release.fixture.json").read_text(encoding="utf-8"))
    found = verify(manifest)
    if found:
        raise SystemExit("\n".join(found))
    print("PASS synthetic release identity and promotion dry-run")
    print("UNVERIFIED registry, signature/attestation, SBOM content, Compose, Nginx, TLS and real environments")
