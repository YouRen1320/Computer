#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
if [[ -n "${PYTHON_BIN:-}" ]]; then
  "$PYTHON_BIN" -m pytest -q -p no:cacheprovider
else
  uv run --no-project --python 3.14 --with 'pytest==9.1.1' -- python -m pytest -q -p no:cacheprovider
fi
