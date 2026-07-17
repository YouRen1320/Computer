#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

grep -Fq '"type": "module"' "$ROOT/package.json"
grep -Fq 'from "./status-label.js"' "$ROOT/src/main.js"
grep -Fq 'import { statusLabel }' "$ROOT/src/main.js"
node --check "$ROOT/src/status-label.js"
node --check "$ROOT/src/main.js"
node "$ROOT/src/main.js" >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"
cmp "$ROOT/expected.stdout" "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"

echo "PASS runtime-esm private solution exit=0"
