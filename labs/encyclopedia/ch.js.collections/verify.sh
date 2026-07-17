#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

node "$ROOT/src/collection-contract.mjs" >"$TMP_DIR/baseline.stdout" 2>"$TMP_DIR/baseline.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/baseline.stdout"
test ! -s "$TMP_DIR/baseline.stderr"

duplicate_exit=0
node "$ROOT/faults/duplicate-key-loss.mjs" >"$TMP_DIR/duplicate.stdout" 2>"$TMP_DIR/duplicate.stderr" || duplicate_exit=$?
if (( duplicate_exit == 0 )); then
  echo "FAIL collections lab: duplicate-key fault did not fail" >&2
  exit 1
fi
grep -Fq "DUPLICATE_KEY_LOSS_OVERWROTE_FIRST" "$TMP_DIR/duplicate.stderr"
test ! -s "$TMP_DIR/duplicate.stdout"

alias_exit=0
node "$ROOT/faults/reference-aliasing.mjs" >"$TMP_DIR/alias.stdout" 2>"$TMP_DIR/alias.stderr" || alias_exit=$?
if (( alias_exit == 0 )); then
  echo "FAIL collections lab: reference-aliasing fault did not fail" >&2
  exit 1
fi
grep -Fq "REFERENCE_ALIASING_NESTED_PATH" "$TMP_DIR/alias.stderr"
test ! -s "$TMP_DIR/alias.stdout"

mutation_exit=0
node "$ROOT/faults/input-mutation.mjs" >"$TMP_DIR/mutation.stdout" 2>"$TMP_DIR/mutation.stderr" || mutation_exit=$?
if (( mutation_exit == 0 )); then
  echo "FAIL collections lab: input-mutation fault did not fail" >&2
  exit 1
fi
grep -Fq "INPUT_MUTATION_SORT_CHANGED_CALLER" "$TMP_DIR/mutation.stderr"
test ! -s "$TMP_DIR/mutation.stdout"

echo "PASS collections lab baseline=0 duplicate=$duplicate_exit alias=$alias_exit mutation=$mutation_exit"
