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

expect_type_fault() {
  local file="$1"
  local marker="$2"
  local diagnostic="$3"
  local output
  local status

  set +e
  output="$(pnpm exec tsc --ignoreConfig --noEmit --strict --exactOptionalPropertyTypes --noUncheckedIndexedAccess --target ES2022 --module NodeNext --moduleResolution NodeNext --pretty false "$file" 2>&1)"
  status=$?
  set -e

  if [[ $status -eq 0 || "$output" != *"$file"* || "$output" != *"$diagnostic"* ]]; then
    echo "expected $marker with $diagnostic in $file" >&2
    echo "$output" >&2
    exit 1
  fi
  echo "$marker"
}

expect_runtime_fault() {
  local output
  local status

  set +e
  output="$(node faults/runtime-confusion.mjs 2>&1)"
  status=$?
  set -e

  if [[ $status -eq 0 || "$output" != *"TYPE_RUNTIME_CONFUSION_FAULT"* ]]; then
    echo "runtime type-erasure fixture did not fail as expected" >&2
    echo "$output" >&2
    exit 1
  fi
  echo "TYPE_RUNTIME_CONFUSION_FAULT"
}

cd "$ROOT_DIR"
pnpm install --offline --frozen-lockfile --ignore-scripts >/dev/null
[[ "$(pnpm exec tsc --version)" == "Version 7.0.2" ]]
pnpm exec tsc --project tsconfig.json --noEmit --pretty false
pnpm exec tsc --project tsconfig.emit.json --pretty false
[[ "$(node .verify-dist/baseline.js)" == "LAB_TYPESCRIPT_BASELINE_PASS" ]]
expect_type_fault faults/wrong-shape.ts SHAPE_FAULT TS2345
expect_type_fault faults/wrong-function.ts FUNCTION_SIGNATURE_FAULT TS2322
expect_type_fault faults/unsafe-optional.ts UNSAFE_OPTIONAL_ACCESS_FAULT TS18048
expect_runtime_fault
echo "TYPESCRIPT_FOUNDATIONS_LAB_PASS"
