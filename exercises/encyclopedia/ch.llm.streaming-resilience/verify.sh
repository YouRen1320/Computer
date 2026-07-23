#!/bin/sh
set -u
cd "$(dirname "$0")"
if uv run --python 3.14 --with pytest==9.1.1 pytest -q; then
  printf '%s\n' 'UNEXPECTED_GREEN unsafe stream consumer passed' >&2
  exit 1
fi
printf '%s\n' 'EXPECTED_RED unbounded retry/false completion/replayed side effect detected'
exit 41
