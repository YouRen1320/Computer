#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$ROOT/.verify-$$"
DEV_PID=""
PREVIEW_PID=""
export CI=true

cleanup() {
  [[ -z "$DEV_PID" ]] || kill "$DEV_PID" 2>/dev/null || true
  [[ -z "$PREVIEW_PID" ]] || kill "$PREVIEW_PID" 2>/dev/null || true
  rm -rf "$TMP_DIR" "$ROOT/node_modules" "$ROOT/dist"
}
trap cleanup EXIT

wait_for_url() {
  local url="$1"
  local output="$2"
  for _ in {1..50}; do
    if curl -fsS "$url" >"$output" 2>/dev/null; then return 0; fi
    sleep 0.1
  done
  return 1
}

mkdir -p "$TMP_DIR/fault/src" "$TMP_DIR/dist"
cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts
node scripts/check-entry.mjs >"$TMP_DIR/entry.log"

pnpm exec vite --host 127.0.0.1 --port 43191 --strictPort >"$TMP_DIR/dev.log" 2>&1 &
DEV_PID=$!
wait_for_url 'http://127.0.0.1:43191/' "$TMP_DIR/dev-index.html"
wait_for_url 'http://127.0.0.1:43191/src/App.vue' "$TMP_DIR/dev-app.js"
grep -Fq 'FactoryCare Vite 三链实验' "$TMP_DIR/dev-index.html"
grep -Fq 'FACTORYCARE_VITE_CHAIN_OK' "$TMP_DIR/dev-app.js"
kill "$DEV_PID"
wait "$DEV_PID" 2>/dev/null || true
DEV_PID=""

pnpm exec vite build --outDir "$TMP_DIR/dist" --emptyOutDir --sourcemap >"$TMP_DIR/build.log"
test -f "$TMP_DIR/dist/index.html"
find "$TMP_DIR/dist/assets" -name '*.map' -type f | grep -q .
rg -q 'FACTORYCARE_VITE_CHAIN_OK' "$TMP_DIR/dist/assets"

pnpm exec vite preview --host 127.0.0.1 --port 43192 --strictPort --outDir "$TMP_DIR/dist" >"$TMP_DIR/preview.log" 2>&1 &
PREVIEW_PID=$!
wait_for_url 'http://127.0.0.1:43192/' "$TMP_DIR/preview-index.html"
grep -Fq 'FactoryCare Vite 三链实验' "$TMP_DIR/preview-index.html"
kill "$PREVIEW_PID"
wait "$PREVIEW_PID" 2>/dev/null || true
PREVIEW_PID=""

cp package.json index.html tsconfig.json vite.config.ts "$TMP_DIR/fault/"
cp src/main.ts src/App.vue "$TMP_DIR/fault/src/"
perl -0pi -e 's#</template>##' "$TMP_DIR/fault/src/App.vue"
set +e
pnpm exec vite build "$TMP_DIR/fault" --outDir "$TMP_DIR/fault-dist" --emptyOutDir >"$TMP_DIR/fault.out" 2>"$TMP_DIR/fault.err"
fault_status=$?
set -e
[[ $fault_status -ne 0 ]]
rg -q 'App\.vue|plugin:vite:vue|end tag|Element is missing' "$TMP_DIR/fault.err" "$TMP_DIR/fault.out"

echo "PASS vite-sfc lab dev=0 build=0 preview=0 injected-sfc-failure=$fault_status rerun=green source-map=present"
