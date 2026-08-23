#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 scripts/check.py
echo "PYTHON_RUNTIME_UV_LAB_GREEN contract=verified"
