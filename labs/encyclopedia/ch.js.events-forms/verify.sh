#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$ROOT/node_modules"' EXIT

cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts >"$TMP_DIR/install.log"
node src/event-contract.mjs >"$TMP_DIR/baseline.stdout" 2>"$TMP_DIR/baseline.stderr"
cmp expected.stdout "$TMP_DIR/baseline.stdout"
test ! -s "$TMP_DIR/baseline.stderr"

run_fault() {
  local file="$1"
  local marker="$2"
  local name="$3"
  local exit_code=0
  node "$file" >"$TMP_DIR/$name.stdout" 2>"$TMP_DIR/$name.stderr" || exit_code=$?
  if (( exit_code == 0 )); then
    echo "FAIL events-forms lab: $name fault did not fail" >&2
    exit 1
  fi
  grep -Fq "$marker" "$TMP_DIR/$name.stderr"
  test ! -s "$TMP_DIR/$name.stdout"
}

run_fault faults/duplicate-listener.mjs DUPLICATE_EVENT_HANDLER duplicate
run_fault faults/default-action-loss.mjs DEFAULT_ACTION_LOSS default
run_fault faults/target-current-target.mjs EVENT_TARGET_CONFUSION target

echo "PASS events-forms lab baseline=5 faults=3 simulator=happy-dom@17.6.3"
