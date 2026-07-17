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
grep -Fq ':key="order.id"' src/WorkOrderBoard.vue
grep -Fq ':key="index"' faults/IndexKeyList.vue
grep -Fq '@click.stop="openDetails(order.id)"' src/WorkOrderBoard.vue
test -f "$TMP_DIR/dist/index.html"
echo "PASS template-directives lab cases=10 build=0 empty-one-many=green events=green healthy-identity=stable injected-index-identity=drift key-warnings=0"
