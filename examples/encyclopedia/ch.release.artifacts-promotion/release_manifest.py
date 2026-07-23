"""Release-manifest validation centered on immutable content identities."""

from __future__ import annotations

import re
from typing import Any


COMMIT = re.compile(r"^[0-9a-f]{40}$")
DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")


def validate(manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if not COMMIT.fullmatch(str(manifest.get("commit", ""))):
        errors.append("commit must be a full 40-hex Git identity")
    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, dict) or not artifacts:
        errors.append("artifacts must be a non-empty mapping")
    else:
        for name, record in artifacts.items():
            if not isinstance(record, dict) or not DIGEST.fullmatch(str(record.get("digest", ""))):
                errors.append(f"artifact digest is missing or mutable: {name}")
            if not DIGEST.fullmatch(str(record.get("sbom_digest", ""))):
                errors.append(f"SBOM digest is missing: {name}")
    gates = manifest.get("quality_gates")
    if not isinstance(gates, dict) or not gates or any(value != "success" for value in gates.values()):
        errors.append("every required quality gate must be recorded as success")
    if not manifest.get("provenance_uri"):
        errors.append("provenance_uri is required")
    return errors


def same_artifact_in_every_environment(resolved: dict[str, str]) -> bool:
    return bool(resolved) and all(DIGEST.fullmatch(item) for item in resolved.values()) and len(set(resolved.values())) == 1
