#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
export UV_NO_PROGRESS=1
cd "$(dirname "$0")"
uv run \
  --python 3.14 \
  --with 'fastapi==0.139.2' \
  --with 'pydantic==2.13.4' \
  --with 'starlette==1.3.1' \
  --with 'httpx==0.28.1' \
  python scripts/check.py
