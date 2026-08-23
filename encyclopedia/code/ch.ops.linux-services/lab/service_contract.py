"""Static contract validator for a systemd unit and its declared filesystem policy.

This deliberately does not pretend to run systemd on the macOS authoring host.
"""

from __future__ import annotations

import configparser
import json
import shlex
from pathlib import Path


def load_unit(path: Path) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    with path.open(encoding="utf-8") as source:
        parser.read_file(source)
    return parser


def validate(unit_path: Path, contract_path: Path) -> list[str]:
    unit = load_unit(unit_path)
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    service = unit["Service"] if unit.has_section("Service") else {}
    errors: list[str] = []

    user = service.get("User", "root")
    group = service.get("Group", "root")
    if user in {"", "root", "0"}:
        errors.append("Service.User must be a dedicated non-root account")
    if user != contract["user"] or group != contract["group"]:
        errors.append("unit identity differs from the declared account contract")

    command = shlex.split(service.get("ExecStart", ""))
    if not command or not command[0].startswith("/"):
        errors.append("ExecStart executable must be an absolute path")
    elif command[0] != contract["executable"]:
        errors.append("ExecStart executable differs from the deployed artifact")

    if service.get("WorkingDirectory") != contract["working_directory"]:
        errors.append("WorkingDirectory differs from the directory contract")
    writable = set(shlex.split(service.get("ReadWritePaths", "")))
    if not set(contract["writable_paths"]).issubset(writable):
        errors.append("declared data paths are not all listed in ReadWritePaths")
    if service.get("NoNewPrivileges", "").lower() != "true":
        errors.append("NoNewPrivileges=true is required")
    if service.get("PrivateTmp", "").lower() != "true":
        errors.append("PrivateTmp=true is required")
    if service.get("KillSignal") != "SIGTERM":
        errors.append("KillSignal must make the graceful-stop contract explicit")
    return errors
