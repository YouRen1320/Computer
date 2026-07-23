"""Conservative scanner for the controlled workflow fixture, not a YAML engine."""

from pathlib import Path
import re


ROOT = Path(__file__).parent
PIN = re.compile(r"uses:\s*[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}\s*$", re.M)
USES = re.compile(r"uses:\s*([^\s]+)")


def audit(text: str) -> list[str]:
    errors: list[str] = []
    if not re.search(r"^permissions:\s*\n\s+contents:\s+read\s*$", text, re.M):
        errors.append("workflow must declare least-privilege contents: read")
    if not re.search(r"^concurrency:\s*\n(?:\s+.*\n){1,3}", text, re.M):
        errors.append("workflow must declare concurrency")
    for use in USES.findall(text):
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}", use):
            errors.append(f"action is not pinned to a full commit SHA: {use}")
    for required in ("java-test", "web-test", "python-test"):
        if f"  {required}:" not in text:
            errors.append(f"missing required job: {required}")
    needs = re.search(r"needs:\s*\[([^]]+)\]", text)
    needed = set(part.strip() for part in needs.group(1).split(",")) if needs else set()
    if needed != {"java-test", "web-test", "python-test"}:
        errors.append("release-gate must need every required test job")
    if text.count("if: always()") < 3 or text.count("actions/upload-artifact@") < 3:
        errors.append("each test family must retain evidence even on failure")
    if "pnpm install --frozen-lockfile" not in text or "uv sync --locked" not in text:
        errors.append("dependency installation must enforce lock files")
    return errors


if __name__ == "__main__":
    source = (ROOT / "ci.fixture.yml").read_text(encoding="utf-8")
    found = audit(source)
    if found:
        raise SystemExit("\n".join(found))
    print("PASS controlled workflow source contract")
    print("UNVERIFIED GitHub-hosted runner, required-check settings, secrets, artifacts and real workflow run")
