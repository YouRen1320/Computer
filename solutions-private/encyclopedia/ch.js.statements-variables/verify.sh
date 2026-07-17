#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

grep -Fq 'const workOrderId = "WO-1001";' "$ROOT/src/state-trace.mjs"
grep -Fq 'let currentStatus = "CREATED";' "$ROOT/src/state-trace.mjs"
node --check "$ROOT/src/state-trace.mjs"
node "$ROOT/src/state-trace.mjs" >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"

echo "PASS statements-variables private solution exit=0"
