#!/usr/bin/env bash
set -euo pipefail

# Local mechanical checks must not install a different pnpm into the user's global tool cache.
export npm_config_manage_package_manager_versions=false

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR" "$ROOT_DIR/node_modules" "$ROOT_DIR/.verify-dist"
}
trap cleanup EXIT

cd "$ROOT_DIR"
pnpm install --offline --frozen-lockfile --ignore-scripts >/dev/null
[[ "$(pnpm exec tsc --version)" == "Version 7.0.2" ]]
pnpm exec tsc --project tsconfig.json --noEmit --pretty false
pnpm exec tsc --project tsconfig.emit.json --pretty false
node .verify-dist/run.js >"$TMP_DIR/actual.stdout"
diff -u expected.stdout "$TMP_DIR/actual.stdout"
printf '%s\n' 'EXAMPLE_GREEN chapter=ch.ts.modeling-narrowing oracle=typecheck-runtime-output-match'
