#!/bin/sh
set -u
cd "$(dirname "$0")"
if uv run --python 3.14 --with pytest==9.1.1 pytest -q; then
  printf '%s\n' 'UNEXPECTED_GREEN broken API client escaped the exercise oracle' >&2
  exit 1
fi
printf '%s\n' 'EXPECTED_RED secret/model/usage/provider-error contract violations detected'
exit 41
