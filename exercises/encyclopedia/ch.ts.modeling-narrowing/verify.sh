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

set +e
compile_output="$(pnpm exec tsc --project tsconfig.json --noEmit --pretty false 2>&1)"
compile_rc=$?
set -e
if [[ $compile_rc -ne 0 ]]; then
  echo "$compile_output" >&2
  echo "MODELING_NARROWING_EXERCISE_RED" >&2
  exit 1
fi

pnpm exec tsc --project tsconfig.emit.json --pretty false
node .verify-dist/exercise.js >"$TMP_DIR/actual.stdout"
diff -u expected.stdout "$TMP_DIR/actual.stdout"
