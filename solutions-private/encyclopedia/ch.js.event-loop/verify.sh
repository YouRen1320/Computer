#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$ROOT/node_modules"' EXIT

cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts >"$TMP_DIR/install.log"
node src/solution.mjs >"$TMP_DIR/actual.stdout" 2>"$TMP_DIR/actual.stderr"
cmp expected.stdout "$TMP_DIR/actual.stdout"
test ! -s "$TMP_DIR/actual.stderr"

echo "PASS event-loop private assertions=9 node=$(node --version)"
