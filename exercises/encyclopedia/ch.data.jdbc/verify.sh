#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/factorycare-jdbc-exercise.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
if ruby "$ROOT/oracle.rb" "$ROOT/answer.json" >"$TMP_ROOT/actual.out" 2>"$TMP_ROOT/error.out"; then
  echo "starter unexpectedly passed" >&2
  exit 1
fi
grep -F "answer-error=untrusted value must use a parameter slot" "$TMP_ROOT/error.out" >/dev/null
echo "starter-status=EXPECTED_RED|reason=string-concatenation"
