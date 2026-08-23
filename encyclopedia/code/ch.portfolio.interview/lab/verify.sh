#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PYTHONDONTWRITEBYTECODE=1 python3 audit_claims.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v
