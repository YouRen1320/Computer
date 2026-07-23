"""Reference policy for the public exercise; still a local model only."""


def release_allowed(report: dict) -> bool:
    schema_ok = not report.get("unknown_config", [])
    surfaces_ok = not report.get("secret_marker_surfaces", [])
    rotation_ok = (not report.get("old_credential_valid", True)
                   and report.get("new_credential_valid", False))
    supply_chain_ok = report.get("sbom_complete", False)
    exploitability_ok = not report.get("reachable_known_exploited", False)
    return all((schema_ok, surfaces_ok, rotation_ok, supply_chain_ok, exploitability_ok))
