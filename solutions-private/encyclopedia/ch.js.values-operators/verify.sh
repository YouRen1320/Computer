#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

grep -Fq 'retryCount === 0' "$ROOT/src/value-contract.mjs"
grep -Fq 'retryCount ?? 3' "$ROOT/src/value-contract.mjs"
node --check "$ROOT/src/value-contract.mjs"
node "$ROOT/src/value-contract.mjs" >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"

echo "PASS values-operators private solution exit=0"
