#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
uv run --no-project --with pandas --with pytest pytest -q -p no:cacheprovider
