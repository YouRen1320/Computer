#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
export UV_NO_PROGRESS=1
cd "$(dirname "$0")"
uv run --python 3.14 --with 'pandas==3.0.5' python scripts/check.py
