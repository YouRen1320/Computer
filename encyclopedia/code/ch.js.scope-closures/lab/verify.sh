#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

node "$ROOT/src/closure-contract.mjs" >"$TMP_DIR/baseline.stdout" 2>"$TMP_DIR/baseline.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/baseline.stdout"
test ! -s "$TMP_DIR/baseline.stderr"

loop_exit=0
node "$ROOT/faults/loop-capture.mjs" >"$TMP_DIR/loop.stdout" 2>"$TMP_DIR/loop.stderr" || loop_exit=$?
if (( loop_exit == 0 )); then
  echo "FAIL scope-closures lab: loop-capture fault did not fail" >&2
  exit 1
fi
grep -Fq 'LOOP_CAPTURE_SHARED_FINAL_BINDING' "$TMP_DIR/loop.stderr"
test ! -s "$TMP_DIR/loop.stdout"

shadow_exit=0
node "$ROOT/faults/shadowing.mjs" >"$TMP_DIR/shadow.stdout" 2>"$TMP_DIR/shadow.stderr" || shadow_exit=$?
if (( shadow_exit == 0 )); then
  echo "FAIL scope-closures lab: shadowing fault did not fail" >&2
  exit 1
fi
grep -Fq 'SHADOWING_UPDATED_WRONG_BINDING' "$TMP_DIR/shadow.stderr"
test ! -s "$TMP_DIR/shadow.stdout"

shared_exit=0
node "$ROOT/faults/shared-state.mjs" >"$TMP_DIR/shared.stdout" 2>"$TMP_DIR/shared.stderr" || shared_exit=$?
if (( shared_exit == 0 )); then
  echo "FAIL scope-closures lab: shared-state fault did not fail" >&2
  exit 1
fi
grep -Fq 'UNEXPECTED_SHARED_CLOSURE_STATE' "$TMP_DIR/shared.stderr"
test ! -s "$TMP_DIR/shared.stdout"

echo "PASS scope-closures lab baseline=0 loop=$loop_exit shadow=$shadow_exit shared=$shared_exit"
