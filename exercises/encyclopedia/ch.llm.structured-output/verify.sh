#!/bin/sh
set -u
cd "$(dirname "$0")"
if uv run --python 3.14 --with pytest==9.1.1 pytest -q; then
  printf '%s\n' 'UNEXPECTED_GREEN unsafe structured-output exercise passed' >&2
  exit 1
fi
printf '%s\n' 'EXPECTED_RED unversioned permissive schema and silent repair detected'
exit 41
