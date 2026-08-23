#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
cd "$(dirname "$0")"
if [[ -n "${PYTHON_BIN:-}" ]]; then
  "$PYTHON_BIN" verify.py
else
  uv run --no-project --python 3.14 --with 'torch==2.13.0' -- python verify.py
fi
