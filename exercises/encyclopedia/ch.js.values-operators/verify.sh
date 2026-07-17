#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

node --check "$ROOT/src/value-contract.mjs"
if ! node "$ROOT/src/value-contract.mjs" >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"; then
  cat "$TMP_DIR/actual.stderr" >&2
  exit 1
fi

if ! grep -Fq 'retryCount === 0' "$ROOT/src/value-contract.mjs"; then
  echo "VALUES_OPERATORS_EXERCISE_RED: STRICT_EQUALITY_REQUIRED" >&2
  exit 1
fi
if ! grep -Fq 'retryCount ?? 3' "$ROOT/src/value-contract.mjs"; then
  echo "VALUES_OPERATORS_EXERCISE_RED: NULLISH_COALESCING_REQUIRED" >&2
  exit 1
fi

cmp "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"
echo "PASS values-operators exercise exit=0"
