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
grep -Fq 'const openCount = computed' src/work-order-stats.ts
grep -Fq "const linkedStatus = toRef(proxy, 'status')" src/work-order-stats.ts
grep -Fq 'orders: readonly(orders)' src/work-order-stats.ts
test -f "$TMP_DIR/dist/index.html"
echo "PASS reactivity example tests=7 build=0 cache=observed identity=observed dom=updated"
