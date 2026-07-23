#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PYTHONDONTWRITEBYTECODE=1 python3 supply_chain_lab.py >/dev/null
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v
