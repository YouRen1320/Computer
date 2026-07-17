#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$ROOT/node_modules" "$ROOT/dist" "$ROOT/playwright-report" "$ROOT/test-results"' EXIT
export CI=true

cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts
pnpm test:component >"$TMP_DIR/component.log"
pnpm exec vite build --outDir "$TMP_DIR/dist" --emptyOutDir >"$TMP_DIR/build.log"
node scripts/check-evidence-boundaries.mjs >"$TMP_DIR/evidence.log"
test -f "$TMP_DIR/dist/index.html"
echo "PASS component-testing lab cases=10 faults=4 build=0 e2e-spec=checked browser-e2e=UNVERIFIED"
