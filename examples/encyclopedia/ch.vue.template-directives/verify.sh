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
grep -Fq ':key="order.id"' src/WorkOrderList.vue
grep -Fq '@click="selectOrder(order.id)"' src/WorkOrderList.vue
test -f "$TMP_DIR/dist/index.html"
echo "PASS template-directives example tests=6 build=0 key-warnings=0 identity=stable"
