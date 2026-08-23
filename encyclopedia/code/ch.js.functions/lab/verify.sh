#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

node "$ROOT/src/function-contract.mjs" >"$TMP_DIR/baseline.stdout" 2>"$TMP_DIR/baseline.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/baseline.stdout"
test ! -s "$TMP_DIR/baseline.stderr"

parameter_exit=0
node "$ROOT/faults/parameter-order.mjs" >"$TMP_DIR/parameter.stdout" 2>"$TMP_DIR/parameter.stderr" || parameter_exit=$?
if (( parameter_exit == 0 )); then
  echo "FAIL functions lab: parameter-order fault did not fail" >&2
  exit 1
fi
grep -Fq 'PARAMETER_ORDER_CONTRACT_VIOLATION' "$TMP_DIR/parameter.stderr"
test ! -s "$TMP_DIR/parameter.stdout"

return_exit=0
node "$ROOT/faults/missing-return.mjs" >"$TMP_DIR/return.stdout" 2>"$TMP_DIR/return.stderr" || return_exit=$?
if (( return_exit == 0 )); then
  echo "FAIL functions lab: missing-return fault did not fail" >&2
  exit 1
fi
grep -Fq 'MISSING_RETURN_PRODUCED_UNDEFINED' "$TMP_DIR/return.stderr"
test ! -s "$TMP_DIR/return.stdout"

side_effect_exit=0
node "$ROOT/faults/shared-side-effect.mjs" >"$TMP_DIR/side.stdout" 2>"$TMP_DIR/side.stderr" || side_effect_exit=$?
if (( side_effect_exit == 0 )); then
  echo "FAIL functions lab: shared-side-effect fault did not fail" >&2
  exit 1
fi
grep -Fq 'UNEXPECTED_SHARED_SIDE_EFFECT' "$TMP_DIR/side.stderr"
test ! -s "$TMP_DIR/side.stdout"

echo "PASS functions lab baseline=0 parameter=$parameter_exit return=$return_exit side_effect=$side_effect_exit"
