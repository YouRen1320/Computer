#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$ROOT/node_modules"' EXIT
export CI=true
export NO_COLOR=1

cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts >"$TMP_DIR/install.log"
pnpm exec vitest run tests/work-order-summary.test.mjs --reporter=dot >"$TMP_DIR/test.log" 2>&1
grep -Eq 'Tests[[:space:]]+7 passed' "$TMP_DIR/test.log"

echo "PASS testing-debugging example tests=7 vitest=$(pnpm exec vitest --version | awk '{print $2}') node=$(node --version)"
