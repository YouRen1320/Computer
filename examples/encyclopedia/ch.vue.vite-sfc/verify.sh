#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$ROOT/node_modules" "$ROOT/dist"' EXIT
export CI=true

NODE_VERSION="$(node --version)"
NODE_MINOR_OK="$(node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.stdout.write(String(a>22 || (a===22&&b>=12) || (a===20&&b>=19)))')"
[[ "$NODE_MINOR_OK" == "true" ]] || { echo "FAIL unsupported Node $NODE_VERSION" >&2; exit 2; }

cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts
pnpm exec vite build --outDir "$TMP_DIR/dist" --emptyOutDir

grep -Fq 'id="app"' index.html
grep -Fq "mount('#app')" src/main.ts
grep -Fq '<script setup lang="ts">' src/App.vue
grep -Fq '<style scoped>' src/App.vue
test -f "$TMP_DIR/dist/index.html"
rg -q 'VITE_SFC_ENTRY_OK' "$TMP_DIR/dist/assets"

echo "PASS vite-sfc example node=$NODE_VERSION build=0 entry=matched sfc=transformed"
