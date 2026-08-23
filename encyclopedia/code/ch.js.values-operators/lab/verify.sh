#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

node "$ROOT/src/value-matrix.mjs" >"$TMP_DIR/baseline.stdout" 2>"$TMP_DIR/baseline.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/baseline.stdout"
test ! -s "$TMP_DIR/baseline.stderr"

loose_exit=0
node "$ROOT/faults/loose-equality.mjs" >"$TMP_DIR/loose.stdout" 2>"$TMP_DIR/loose.stderr" || loose_exit=$?
if (( loose_exit == 0 )); then
  echo "FAIL values-operators lab: loose equality fault did not fail" >&2
  exit 1
fi
grep -Fq 'LOOSE_EQUALITY_COLLAPSED_TYPES' "$TMP_DIR/loose.stderr"
test ! -s "$TMP_DIR/loose.stdout"

coercion_exit=0
node "$ROOT/faults/implicit-coercion.mjs" >"$TMP_DIR/coercion.stdout" 2>"$TMP_DIR/coercion.stderr" || coercion_exit=$?
if (( coercion_exit == 0 )); then
  echo "FAIL values-operators lab: implicit coercion fault did not fail" >&2
  exit 1
fi
grep -Fq 'IMPLICIT_PLUS_COERCION_CHANGED_RESULT' "$TMP_DIR/coercion.stderr"
test ! -s "$TMP_DIR/coercion.stdout"

nullish_exit=0
node "$ROOT/faults/nullish-value-loss.mjs" >"$TMP_DIR/nullish.stdout" 2>"$TMP_DIR/nullish.stderr" || nullish_exit=$?
if (( nullish_exit == 0 )); then
  echo "FAIL values-operators lab: nullish fallback fault did not fail" >&2
  exit 1
fi
grep -Fq 'NULLISH_FALLBACK_LOST_ZERO' "$TMP_DIR/nullish.stderr"
test ! -s "$TMP_DIR/nullish.stdout"

echo "PASS values-operators lab baseline=0 loose=$loose_exit coercion=$coercion_exit nullish=$nullish_exit"
