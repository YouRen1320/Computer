#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
command -v uv >/dev/null || { echo "uv is required" >&2; exit 2; }
export PYTHONDONTWRITEBYTECODE=1
uv run --no-project --with pytest pytest -q -p no:cacheprovider
