#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

node --check "$ROOT/src/closure-contract.mjs"
node "$ROOT/src/closure-contract.mjs" >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"

echo "PASS scope-closures private solution exit=0"
