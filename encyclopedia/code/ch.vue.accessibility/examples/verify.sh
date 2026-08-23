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
node scripts/check-static-a11y.mjs >"$TMP_DIR/static.log"
test -f "$TMP_DIR/dist/index.html"
echo "PASS vue-accessibility example cases=9 build=0 semantic-dom=green keyboard-events=green at-screen-reader=UNVERIFIED manual-visual=UNVERIFIED"
