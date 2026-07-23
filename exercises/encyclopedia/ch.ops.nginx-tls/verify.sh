#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
if PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v; then
  printf '%s\n' 'UNEXPECTED_GREEN incomplete Nginx audit escaped the oracle' >&2
  exit 1
fi
printf '%s\n' 'EXPECTED_RED forwarded-header, SPA fallback, chain and cache faults detected'
exit 41
