"""Reference implementation for the service-isolation exercise."""

from configparser import ConfigParser
from pathlib import Path


def validate_unit(path: Path) -> list[str]:
    parser = ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read(path, encoding="utf-8")
    if not parser.has_section("Service"):
        return ["Service section is required"]
    service = parser["Service"]
    errors: list[str] = []
    if service.get("User", "root") in {"", "root", "0"}:
        errors.append("User must be a dedicated non-root account")
    if not service.get("ExecStart", "").startswith("/"):
        errors.append("ExecStart must be absolute")
    if service.get("NoNewPrivileges", "").lower() != "true":
        errors.append("NoNewPrivileges=true is required")
    return errors
