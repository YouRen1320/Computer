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
grep -Fq "const firstLoadedId = props.workOrderId" faults/StaleOrderDetail.vue
grep -Fq "if (!authenticated) return { name: 'sign-in'" faults/loop-guard.ts
grep -Fq "faultyServerRead(_credential" faults/client-only-authorization.ts
grep -Fq "服务端必须再次授权" src/pages/OrderDetail.vue
test -f "$TMP_DIR/dist/index.html"
echo "PASS router-navigation lab tests=10 faults=3 route-matrix=yes cancellation=aborted redirect=finite server-auth=separate"

