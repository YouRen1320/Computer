#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
command -v uv >/dev/null || { echo "UNEXPECTED RED: uv is required" >&2; exit 2; }
export PYTHONDONTWRITEBYTECODE=1
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT
uv run --no-project --with pytest pytest -q -p no:cacheprovider >"$log_file" 2>&1
status=$?
cat "$log_file"
if [[ $status -ne 0 ]] && grep -q 'DID NOT RAISE' "$log_file"; then
  echo "EXPECTED RED: repository failure was swallowed and falsely reported as CLOSED" >&2
  exit 1
fi
echo "UNEXPECTED RESULT: the intended assertion failure was not observed" >&2
exit 2
