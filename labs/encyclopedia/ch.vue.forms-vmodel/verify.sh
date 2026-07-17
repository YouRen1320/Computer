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
grep -Fq "inputElement.value.value = ''" faults/DomOnlyReset.vue
grep -Fq 'Object.assign(draft, emptyDraft())' src/WorkOrderCreationLab.vue
grep -Fq 'toCreateReportRequest(draft)' src/WorkOrderCreationLab.vue
test -f "$TMP_DIR/dist/index.html"
echo "PASS forms-vmodel lab tests=10 build=0 fault=dom-only-reset oracle=four-way-aligned"
