#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PYTHONDONTWRITEBYTECODE=1 python3 audit_fixture.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v
