#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
uv run --isolated --with 'numpy==2.5.0' --with 'pandas==3.0.5' --with 'pytest==9.1.1' pytest -q -p no:cacheprovider
printf '%s\n' 'SOLUTION_GREEN scaling/partition/projection/hypothesis contracts verified'
