#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
output="$(uv run --no-project --with pandas --with pytest pytest -q -p no:cacheprovider 2>&1)"
rc=$?
printf '%s\n' "$output"
if [[ $rc -ne 0 ]] && grep -q 'unknown categories' <<<"$output"; then
  echo "EXPECTED RED: held-out unknown category crashes transform" >&2
  exit 1
fi
echo "UNEXPECTED RESULT: intended unknown-category failure was not observed" >&2
exit 2
