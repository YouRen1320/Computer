"""Intentionally incomplete public exercise. It contains no credential value."""


def release_allowed(report: dict) -> bool:
    # TODO: reject unknown config, secret markers, incomplete SBOM and unsafe rotation.
    return report.get("cve_count", 0) == 0
