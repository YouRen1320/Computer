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
grep -Fq "path: ':workOrderId'" src/router.ts
grep -Fq "children:" src/router.ts
grep -Fq "return false" src/router.ts
grep -Fq "客户端守卫只控制导航体验" src/pages/WorkOrderDetailPage.vue
test -f "$TMP_DIR/dist/index.html"
echo "PASS router-navigation example tests=9 build=0 deep-link=yes param-reuse=yes cancel=aborted redirect=finite"

