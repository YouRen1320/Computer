"""Small Dockerfile policy parser for deterministic teaching fixtures."""

from __future__ import annotations

import json
import re


DIGEST = re.compile(r"@sha256:[0-9a-f]{64}$")


def logical_lines(text: str) -> list[str]:
    lines: list[str] = []
    pending = ""
    for raw in text.splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        pending += stripped[:-1].rstrip() + " " if stripped.endswith("\\") else stripped
        if not stripped.endswith("\\"):
            lines.append(pending.strip())
            pending = ""
    if pending:
        lines.append(pending.strip())
    return lines


def audit(text: str) -> list[str]:
    lines = logical_lines(text)
    errors: list[str] = []
    from_lines = [line for line in lines if line.upper().startswith("FROM ")]
    if len(from_lines) < 2:
        errors.append("a multi-stage build is required")
    for line in from_lines:
        image = line.split()[1]
        if not DIGEST.search(image):
            errors.append(f"base image is not pinned by digest: {image}")
    users = [line.split(maxsplit=1)[1] for line in lines if line.upper().startswith("USER ")]
    if not users or users[-1].split(":", 1)[0] in {"root", "0"}:
        errors.append("final runtime user must be non-root")
    entries = [line.split(maxsplit=1)[1] for line in lines if line.upper().startswith("ENTRYPOINT ")]
    if not entries:
        errors.append("ENTRYPOINT is required")
    else:
        try:
            value = json.loads(entries[-1])
            if not isinstance(value, list) or not value:
                raise ValueError
        except (json.JSONDecodeError, ValueError):
            errors.append("ENTRYPOINT must use non-empty JSON exec form")
    return errors
