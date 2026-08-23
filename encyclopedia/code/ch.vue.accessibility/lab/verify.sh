#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$ROOT/node_modules" "$ROOT/dist"' EXIT
export CI=true
cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts
pnpm test >"$TMP_DIR/test.log"
pnpm exec vite build --outDir "$TMP_DIR/dist" --emptyOutDir >"$TMP_DIR/build.log"
node scripts/check-fault-catalog.mjs >"$TMP_DIR/faults.log"
test -f "$TMP_DIR/dist/index.html"
echo "PASS vue-accessibility lab cases=10 faults=4 build=0 browser-at=UNVERIFIED manual-visual=UNVERIFIED"
