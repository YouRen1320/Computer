#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$ROOT/node_modules"' EXIT

cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts >"$TMP_DIR/install.log"
node src/queue-contract.mjs >"$TMP_DIR/baseline.stdout" 2>"$TMP_DIR/baseline.stderr"
cmp expected.stdout "$TMP_DIR/baseline.stdout"
test ! -s "$TMP_DIR/baseline.stderr"

run_fault() {
  local file="$1"
  local marker="$2"
  local name="$3"
  local exit_code=0
  node "$file" >"$TMP_DIR/$name.stdout" 2>"$TMP_DIR/$name.stderr" || exit_code=$?
  if (( exit_code == 0 )); then
    echo "FAIL event-loop lab: $name fault did not fail" >&2
    exit 1
  fi
  grep -Fq "$marker" "$TMP_DIR/$name.stderr"
  test ! -s "$TMP_DIR/$name.stdout"
}

run_fault faults/promise-as-value.mjs PROMISE_AS_SYNC_VALUE promise-value
run_fault faults/missing-await.mjs MISSING_AWAIT_ORDER missing-await
run_fault faults/async-error-boundary.mjs ASYNC_ERROR_BOUNDARY_LOST error-boundary
run_fault faults/microtask-order.mjs MICROTASK_ORDER_MISREAD microtask-order

echo "PASS event-loop lab baseline=8 faults=4 node=$(node --version)"
