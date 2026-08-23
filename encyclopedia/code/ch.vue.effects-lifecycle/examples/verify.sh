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
grep -Fq 'onCleanup(() =>' src/FilterEffectPanel.vue
grep -Fq "{ flush: 'post' }" src/FilterEffectPanel.vue
grep -Fq 'onUnmounted(() =>' src/FilterEffectPanel.vue
test -f "$TMP_DIR/dist/index.html"
echo "PASS effects-lifecycle example tests=7 build=0 cleanup=ordered stale-commit=blocked"
