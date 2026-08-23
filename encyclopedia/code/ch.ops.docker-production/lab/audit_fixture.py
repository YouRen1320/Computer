"""Static image-source audit. It does not claim to build or scan a real image."""

from pathlib import Path
import re


ROOT = Path(__file__).parent
DIGEST = re.compile(r"@sha256:[0-9a-f]{64}(?:\s|$)")
SECRET_NAMES = re.compile(r"(?:^|/)(?:\.env|id_rsa|.*\.pem|.*\.p12|credentials\.json)$", re.I)


def audit(dockerfile: str, context_files: list[str]) -> list[str]:
    errors: list[str] = []
    from_lines = [line.strip() for line in dockerfile.splitlines() if line.strip().upper().startswith("FROM ")]
    if len(from_lines) < 2:
        errors.append("builder and runtime stages are required")
    if any(not DIGEST.search(line.split(maxsplit=2)[1]) for line in from_lines):
        errors.append("every base image must be pinned by sha256 digest")
    if "COPY --from=build" not in dockerfile:
        errors.append("runtime stage must copy only the built artifact")
    if not re.search(r"^USER\s+(?!root(?:\s|$)|0(?:[:\s]|$))\S+", dockerfile, re.M | re.I):
        errors.append("runtime stage must declare a non-root USER")
    if not re.search(r'^ENTRYPOINT\s+\["', dockerfile, re.M):
        errors.append("ENTRYPOINT must use JSON exec form")
    for name in context_files:
        if SECRET_NAMES.search(name):
            errors.append(f"secret-like file entered build context: {name}")
    return errors


if __name__ == "__main__":
    dockerfile = (ROOT / "Dockerfile.fixture").read_text(encoding="utf-8")
    files = (ROOT / "context-files.txt").read_text(encoding="utf-8").splitlines()
    found = audit(dockerfile, files)
    if found:
        raise SystemExit("\n".join(found))
    print("PASS static Dockerfile and build-context contract")
    print("UNVERIFIED real image build, registry digest, vulnerability scan, PID 1 and read-only runtime")
