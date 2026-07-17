#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$ROOT/node_modules"' EXIT

cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts >"$TMP_DIR/install.log"
node --check src/work-order-board.mjs
node src/demo.mjs >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"
cmp expected.stdout "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"

echo "PASS dom-mutation example simulator=happy-dom@17.6.3 node=$(node --version)"
