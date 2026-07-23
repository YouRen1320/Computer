"""Pure policy model: it never reads or stores a credential value."""
from dataclasses import dataclass
from typing import Any


class PolicyError(ValueError):
    pass


SENSITIVE_CONFIG_KEYS = {"password", "secret", "token", "api_key", "private_key"}


@dataclass(frozen=True)
class SecretReference:
    name: str
    version: str


def resolve_config(
    layers: list[tuple[str, dict[str, str]]],
    *,
    allowed: set[str],
    required: set[str],
) -> dict[str, str]:
    """Merge low-to-high precedence layers and reject unknown/sensitive keys."""
    merged: dict[str, str] = {}
    for source, values in layers:
        unknown = set(values) - allowed
        if unknown:
            raise PolicyError(f"unknown config from {source}: {sorted(unknown)}")
        forbidden = set(values) & SENSITIVE_CONFIG_KEYS
        if forbidden:
            raise PolicyError(f"secret values are not configuration: {sorted(forbidden)}")
        merged.update(values)
    missing = required - set(merged)
    if missing:
        raise PolicyError(f"missing required config: {sorted(missing)}")
    return merged


def audit_surfaces(reports: list[dict[str, Any]]) -> list[str]:
    """Reports contain booleans only; no canary or credential value is accepted."""
    findings: list[str] = []
    for report in reports:
        if "value" in report:
            findings.append(f"{report['surface']}:scanner-input-contained-value")
        if report.get("secret_marker_present") is True:
            findings.append(f"{report['surface']}:secret-marker-present")
    return findings


def audit_sbom(sbom: dict[str, Any], locked: dict[str, str]) -> list[str]:
    findings: list[str] = []
    components = sbom.get("components")
    if not isinstance(components, list):
        return ["sbom:components-missing"]
    seen: dict[str, str] = {}
    for component in components:
        name = component.get("name")
        version = component.get("version")
        if not name or not version:
            findings.append("sbom:component-identity-incomplete")
            continue
        seen[name] = version
        if not component.get("purl"):
            findings.append(f"sbom:{name}:purl-missing")
        if not component.get("hashes"):
            findings.append(f"sbom:{name}:hash-missing")
    if seen != locked:
        findings.append("sbom:lockfile-diff")
    return findings


def vulnerability_decision(finding: dict[str, Any]) -> str:
    """Triage by exploitability and exposure; CVE count alone is not a decision."""
    if finding.get("reachable") and finding.get("known_exploited"):
        return "block-release"
    if finding.get("reachable") and finding.get("severity") in {"CRITICAL", "HIGH"}:
        return "remediate-before-release"
    return "document-and-monitor"


if __name__ == "__main__":
    resolved = resolve_config(
        [("defaults", {"profile": "local", "log_level": "INFO"}),
         ("environment", {"profile": "production"})],
        allowed={"profile", "log_level"},
        required={"profile", "log_level"},
    )
    print({"config": resolved, "secret_reference": SecretReference("database", "v7")})
