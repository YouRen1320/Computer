"""Audit the normalized JSON emitted by docker compose config.

This proves source/config contracts only. It never starts a container.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parent


def load_normalized(path: Path) -> dict:
    env = dict(os.environ)
    env["FACTORYCARE_DB_PASSWORD"] = "local-fixture-not-a-production-secret"
    completed = subprocess.run(
        ["docker", "compose", "--profile", "debug", "-f", str(path), "config", "--format", "json"],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    return json.loads(completed.stdout)


def _mounts(service: dict) -> list[dict]:
    return service.get("volumes", [])


def audit(config: dict) -> list[str]:
    errors: list[str] = []
    services = config.get("services", {})
    required = {"db", "api", "proxy"}
    if not required.issubset(services):
        errors.append("db, api and proxy services are required")
        return errors

    for name, service in services.items():
        image = service.get("image", "")
        if "@sha256:" not in image:
            errors.append(f"{name}: image must be pinned by digest")

    for name, service in services.items():
        if name != "proxy" and service.get("ports"):
            errors.append(f"{name}: only the edge proxy may publish a host port")

    db_mounts = _mounts(services["db"])
    if not any(m.get("type") == "volume" and m.get("target") == "/var/lib/postgresql/data" for m in db_mounts):
        errors.append("db: named volume must persist PostgreSQL data")

    dependency = services["api"].get("depends_on", {}).get("db", {})
    if dependency.get("condition") != "service_healthy":
        errors.append("api: db dependency must wait for service_healthy")
    if "healthcheck" not in services["db"] or "healthcheck" not in services["api"]:
        errors.append("db and api healthchecks are required")

    networks = config.get("networks", {})
    if not networks.get("data", {}).get("internal", False):
        errors.append("data network must be internal")
    if set(services["db"].get("networks", {})) != {"data"}:
        errors.append("db must only join the data network")
    if set(services["proxy"].get("networks", {})) != {"edge"}:
        errors.append("proxy must only join the edge network")
    if not {"data", "edge"}.issubset(services["api"].get("networks", {})):
        errors.append("api must bridge data and edge networks")

    for name in required:
        if services[name].get("restart") not in {"unless-stopped", "on-failure"}:
            errors.append(f"{name}: bounded operational restart policy is required")
    if "debug" not in services.get("toolbox", {}).get("profiles", []):
        errors.append("toolbox must be opt-in through the debug profile")
    return errors


def main() -> None:
    config = load_normalized(ROOT / "compose.fixture.yaml")
    errors = audit(config)
    if errors:
        raise SystemExit("\n".join(errors))
    print("ACTUAL docker compose config parsed and normalized the fixture")
    print("PASS static service, network, volume, health, profile and restart contracts")
    print("UNVERIFIED Docker daemon, image pulls, cold start, health transitions, restart and volume persistence")


if __name__ == "__main__":
    main()
