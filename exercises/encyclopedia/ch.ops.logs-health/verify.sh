#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -v
test_rc=$?
set -e
if [[ $test_rc -eq 0 ]]; then
  echo "UNEXPECTED_GREEN: complete the exercise only in your own working copy" >&2
  exit 42
fi
echo "EXPECTED_RED: correlation and health contracts are intentionally broken" >&2
exit 41
