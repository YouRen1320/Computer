#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
output="$(uv run --no-project --with pytest pytest -q -p no:cacheprovider 2>&1)"
rc=$?
printf '%s\n' "$output"
if [[ $rc -ne 0 ]] && grep -q 'chunk ACL and parent lineage' <<<"$output"; then
  echo "EXPECTED RED: chunks lost ACL and parent lineage" >&2
  exit 1
fi
echo "UNEXPECTED RESULT: intended chunk-lineage failure was not observed" >&2
exit 2
