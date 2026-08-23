#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v
printf '%s\n' 'PASS static Compose policy solution'
printf '%s\n' 'UNVERIFIED daemon cold start, health transition, restart and persistent volume'
