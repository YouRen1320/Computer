#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
if PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v; then
  printf '%s\n' 'UNEXPECTED_GREEN incomplete Docker audit escaped the oracle' >&2
  exit 1
fi
printf '%s\n' 'EXPECTED_RED mutable base, root runtime and secret context were not rejected'
exit 41
