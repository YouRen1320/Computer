#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/factorycare-joins-exercise.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
if ruby "$ROOT/oracle.rb" "$ROOT/answer.sql" >"$TMP_ROOT/actual.out" 2>&1; then
  echo "starter-unexpectedly-passed"
  exit 1
fi
grep -F "answer-error=cartesian source must be replaced by explicit JOIN ON" "$TMP_ROOT/actual.out" >/dev/null
echo "JOINS EXERCISE STARTER EXPECTED FAILURE"
exit 41
