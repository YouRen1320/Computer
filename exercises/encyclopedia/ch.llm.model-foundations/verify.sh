#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
output="$(python3 check.py 2>&1)"
rc=$?
printf '%s\n' "$output"
if [[ $rc -ne 0 ]] && grep -q 'recorded tokenizer count' <<<"$output"; then
  echo "EXPECTED RED: character count was substituted for token budget" >&2
  exit 1
fi
echo "UNEXPECTED RESULT: intended context-budget failure was not observed" >&2
exit 2
