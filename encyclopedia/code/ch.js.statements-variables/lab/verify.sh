#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

node "$ROOT/src/state-trace.mjs" >"$TMP_DIR/baseline.stdout" 2>"$TMP_DIR/baseline.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/baseline.stdout"
test ! -s "$TMP_DIR/baseline.stderr"

undeclared_exit=0
node "$ROOT/faults/undeclared.mjs" >"$TMP_DIR/undeclared.stdout" 2>"$TMP_DIR/undeclared.stderr" || undeclared_exit=$?
if (( undeclared_exit == 0 )); then
  echo "FAIL statements-variables lab: undeclared identifier did not fail" >&2
  exit 1
fi
grep -Fq 'ReferenceError' "$TMP_DIR/undeclared.stderr"
grep -Fq 'workorderId is not defined' "$TMP_DIR/undeclared.stderr"
test ! -s "$TMP_DIR/undeclared.stdout"

const_exit=0
node "$ROOT/faults/const-reassign.mjs" >"$TMP_DIR/const.stdout" 2>"$TMP_DIR/const.stderr" || const_exit=$?
if (( const_exit == 0 )); then
  echo "FAIL statements-variables lab: const reassignment did not fail" >&2
  exit 1
fi
grep -Fq 'TypeError' "$TMP_DIR/const.stderr"
grep -Fq 'Assignment to constant variable' "$TMP_DIR/const.stderr"
test ! -s "$TMP_DIR/const.stdout"

node "$ROOT/faults/order-mismatch.mjs" >"$TMP_DIR/order.stdout" 2>"$TMP_DIR/order.stderr"
test ! -s "$TMP_DIR/order.stderr"
if cmp -s "$ROOT/faults/order-mismatch.expected.stdout" "$TMP_DIR/order.stdout"; then
  echo "FAIL statements-variables lab: wrong execution-order prediction unexpectedly matched" >&2
  exit 1
fi
grep -Fq 'observed=CREATED' "$TMP_DIR/order.stdout"

echo "PASS statements-variables lab baseline=0 reference_error=$undeclared_exit const_error=$const_exit order_mismatch=detected"
