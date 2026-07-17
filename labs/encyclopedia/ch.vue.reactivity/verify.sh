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
grep -Fq 'const openCount = ref' faults/copied-derived-state.ts
grep -Fq 'const openCount = computed' src/stats-model.ts
grep -Fq "const linked = toRef(state, 'status')" src/stats-model.ts
test -f "$TMP_DIR/dist/index.html"
echo "PASS reactivity lab tests=10 build=0 fault=duplicated-derived-state oracle=transition-cache-identity-dom"
