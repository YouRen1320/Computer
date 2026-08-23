#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
cd "$(dirname "$0")"
command -v uvx >/dev/null || { echo "uvx is required" >&2; exit 2; }
uvx --from mypy==2.3.0 mypy --strict --no-incremental --cache-dir=/dev/null --python-version 3.14 solution.py scripts/check.py
python3 scripts/check.py
