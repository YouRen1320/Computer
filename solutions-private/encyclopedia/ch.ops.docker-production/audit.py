"""Reference solution for the static Docker source audit."""

import re


DIGEST = re.compile(r"@sha256:[0-9a-f]{64}(?:\s|$)")
SECRET = re.compile(r"(?:^|/)(?:\.env|id_rsa|.*\.pem|.*\.p12|credentials\.json)$", re.I)


def audit(dockerfile: str, context_files: list[str]) -> list[str]:
    errors: list[str] = []
    from_lines = [line.strip() for line in dockerfile.splitlines() if line.strip().upper().startswith("FROM ")]
    if not from_lines or any(not DIGEST.search(line.split(maxsplit=2)[1]) for line in from_lines):
        errors.append("base image must be pinned by digest")
    users = [line.split(maxsplit=1)[1] for line in dockerfile.splitlines() if line.strip().upper().startswith("USER ")]
    if not users or users[-1].split(":", 1)[0].lower() in {"root", "0"}:
        errors.append("runtime user must be non-root")
    for name in context_files:
        if SECRET.search(name):
            errors.append(f"secret-like file entered build context: {name}")
    return errors
