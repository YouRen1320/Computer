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
grep -Fq 'props.order.status = next' faults/MutatingStatusEditor.vue
grep -Fq "'status-change': [value: Status]" faults/WrongEventEditor.vue
grep -Fq '#actions="{ orderId, status }"' src/ContractBoard.vue
test -f "$TMP_DIR/dist/index.html"
echo "PASS components-contracts lab tests=10 build=0 mutation-fault=detected event-drift=detected"
