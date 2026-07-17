#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

node --check "$ROOT/src/function-contract.mjs"
if ! node "$ROOT/src/function-contract.mjs" >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"; then
  cat "$TMP_DIR/actual.stderr" >&2
  exit 1
fi
cmp "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"

echo "PASS functions exercise exit=0"
