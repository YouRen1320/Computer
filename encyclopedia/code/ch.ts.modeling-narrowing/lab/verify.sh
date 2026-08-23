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
  local rc

  set +e
  output="$(pnpm exec tsc --ignoreConfig --noEmit --strict --target ES2022 --module NodeNext --moduleResolution NodeNext --pretty false "$file" 2>&1)"
  rc=$?
  set -e

  if [[ $rc -eq 0 || "$output" != *"$file"* || "$output" != *"$diagnostic"* ]]; then
    echo "expected $marker with $diagnostic in $file" >&2
    echo "$output" >&2
    exit 1
  fi
  echo "$marker"
}

expect_runtime_fault() {
  local file="$1"
  local marker="$2"
  local output
  local rc

  rm -rf "$TMP_DIR/runtime"
  pnpm exec tsc --ignoreConfig --strict --target ES2022 --module NodeNext --moduleResolution NodeNext --outDir "$TMP_DIR/runtime" --pretty false "$file"
  set +e
  output="$(node "$TMP_DIR/runtime/$(basename "${file%.ts}").js" 2>&1)"
  rc=$?
  set -e

  if [[ $rc -eq 0 || "$output" != *"$marker"* ]]; then
    echo "expected runtime marker $marker from $file" >&2
    echo "$output" >&2
    exit 1
  fi
  echo "$marker"
}

cd "$ROOT_DIR"
pnpm install --offline --frozen-lockfile --ignore-scripts >/dev/null
[[ "$(pnpm exec tsc --version)" == "Version 7.0.2" ]]
pnpm exec tsc --project tsconfig.json --noEmit --pretty false
pnpm exec tsc --project tsconfig.emit.json --pretty false
[[ "$(node .verify-dist/baseline.js)" == "MODELING_NARROWING_LAB_BASELINE_PASS" ]]
expect_type_fault faults/nonexhaustive.ts NONEXHAUSTIVE_STATE_FAULT TS2322
expect_runtime_fault faults/invalid-guard.ts INVALID_GUARD_RUNTIME_FAULT
expect_runtime_fault faults/unsafe-any.ts UNSAFE_ANY_RUNTIME_FAULT
echo "MODELING_NARROWING_LAB_PASS"
