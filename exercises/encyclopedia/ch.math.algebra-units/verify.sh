#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
output="$(python3 check.py 2>&1)"
rc=$?
printf '%s\n' "$output"
if [[ $rc -ne 0 ]] && grep -q 'from 1.5 hours' <<<"$output"; then
  echo "EXPECTED RED: minute-to-hour conversion direction is wrong" >&2
  exit 1
fi
echo "UNEXPECTED RESULT: intended unit failure was not observed" >&2
exit 2
