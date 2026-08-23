#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
cd "$(dirname "$0")"
repository_root="$(cd ../../.. && pwd)"
PYTHONPATH="$repository_root/examples/encyclopedia/ch.python.files-json-time" python3 oracle.py
