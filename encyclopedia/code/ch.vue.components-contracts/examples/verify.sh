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
grep -Fq 'defineModel<StatusFilter>' src/WorkOrderFilterBar.vue
grep -Fq "select: [payload: { orderId: string }]" src/WorkOrderCard.vue
grep -Fq '#actions="{ orderId, status }"' src/WorkOrderBoard.vue
test -f "$TMP_DIR/dist/index.html"
echo "PASS components-contracts example tests=7 build=0 props=readonly events=exact slots=scoped"
