#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/factorycare-psql-exercise.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

if ruby "$ROOT/oracle.rb" >"$TMP_ROOT/actual.out" 2>&1; then
  echo "starter-unexpectedly-passed"
  exit 1
fi

grep -F "plan-error=missing -X" "$TMP_ROOT/actual.out" >/dev/null
echo "PSQL EXERCISE STARTER EXPECTED FAILURE"
