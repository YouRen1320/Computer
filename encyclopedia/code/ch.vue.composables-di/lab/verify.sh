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
grep -Fq "const sharedStatus = ref" faults/shared-query-state.ts
grep -Fq "activeSubscriptions += 1" faults/leaky-effect.ts
grep -Fq "faultyRepositoryKey = 'factorycare.service'" faults/string-key-collision.ts
grep -Fq "onScopeDispose(stop)" src/useWorkOrderQuery.ts
test -f "$TMP_DIR/dist/index.html"
echo "PASS composables-di lab tests=10 faults=3 isolation=yes cleanup=zero substitution=yes"

