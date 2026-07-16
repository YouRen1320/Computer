#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/factorycare-subqueries-cte-lab.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
ruby "$ROOT/oracle.rb" >"$TMP_ROOT/actual.out"
diff -u "$ROOT/expected.out" "$TMP_ROOT/actual.out"
cat "$TMP_ROOT/actual.out"
