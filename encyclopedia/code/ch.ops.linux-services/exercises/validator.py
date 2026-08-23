"""Public exercise: complete every service-isolation check."""

from configparser import ConfigParser
from pathlib import Path


def validate_unit(path: Path) -> list[str]:
    parser = ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read(path, encoding="utf-8")
    service = parser["Service"]
    errors: list[str] = []
    # Deliberately incomplete: add identity and privilege-boundary checks.
    if not service.get("ExecStart", "").startswith("/"):
        errors.append("ExecStart must be absolute")
    return errors
