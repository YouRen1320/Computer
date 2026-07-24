#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$ROOT/node_modules"' EXIT
export CI=true
export NO_COLOR=1

cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts >"$TMP_DIR/install.log"
pnpm exec vitest run tests/baseline.test.mjs --reporter=dot >"$TMP_DIR/baseline.log" 2>&1
grep -Eq 'Tests[[:space:]]+7 passed' "$TMP_DIR/baseline.log"

run_fault() {
  local file="$1"
  local marker="$2"
  local name="$3"
  local exit_code=0
  pnpm exec vitest run "$file" --reporter=dot >"$TMP_DIR/$name.log" 2>&1 || exit_code=$?
  if (( exit_code == 0 )); then
    echo "FAIL testing-debugging lab: $name fault did not fail" >&2
    exit 1
  fi
  grep -Fq "$marker" "$TMP_DIR/$name.log"
}

run_fault faults/untrusted-oracle.test.mjs UNTRUSTED_ORACLE_WRONG_EXPECTED_VALUE oracle
run_fault faults/unawaited-async.test.mjs FALSE_POSITIVE_UNAWAITED_ASYNC_ASSERTION async
run_fault faults/shared-fixture.test.mjs TEST_ISOLATION_LEAK_SHARED_FIXTURE isolation
run_fault faults/silent-catch.test.mjs FALSE_POSITIVE_CAUGHT_ERROR_SILENT catch

echo "PASS testing-debugging lab baseline=7 faults=4 vitest=$(pnpm exec vitest --version | awk '{print $2}')"
