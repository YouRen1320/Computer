#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/factorycare-scalar-exercise.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

if ruby "$ROOT/oracle.rb" "$ROOT/answer.sql" >"$TMP_ROOT/actual.out" 2>&1; then
  echo "starter-unexpectedly-passed"
  exit 1
fi

grep -F "answer-error=timezone must be converted before truncation and date cast" "$TMP_ROOT/actual.out" >/dev/null
echo "SCALAR FUNCTIONS EXERCISE STARTER EXPECTED FAILURE"
