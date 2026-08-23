#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1 UV_NO_PROGRESS=1
cd "$(dirname "$0")"
uv run --isolated --with 'pydantic==2.13.4' python scripts/check.py
