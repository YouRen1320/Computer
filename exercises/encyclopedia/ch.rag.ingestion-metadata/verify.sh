#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
output="$(uv run --no-project --with pytest pytest -q -p no:cacheprovider 2>&1)"
rc=$?
printf '%s\n' "$output"
if [[ $rc -ne 0 ]] && grep -q 'ACL and source lineage' <<<"$output"; then
  echo "EXPECTED RED: normalized text lost ACL/source lineage" >&2
  exit 1
fi
echo "UNEXPECTED RESULT: intended lineage failure was not observed" >&2
exit 2
