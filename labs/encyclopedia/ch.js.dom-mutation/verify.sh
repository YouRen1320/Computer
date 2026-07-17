#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$ROOT/node_modules"' EXIT

cd "$ROOT"
pnpm install --offline --frozen-lockfile --ignore-scripts >"$TMP_DIR/install.log"
node src/dom-contract.mjs >"$TMP_DIR/baseline.stdout" 2>"$TMP_DIR/baseline.stderr"
cmp expected.stdout "$TMP_DIR/baseline.stdout"
test ! -s "$TMP_DIR/baseline.stderr"

run_fault() {
  local file="$1"
  local marker="$2"
  local name="$3"
  local exit_code=0
  node "$file" >"$TMP_DIR/$name.stdout" 2>"$TMP_DIR/$name.stderr" || exit_code=$?
  if (( exit_code == 0 )); then
    echo "FAIL dom-mutation lab: $name fault did not fail" >&2
    exit 1
  fi
  grep -Fq "$marker" "$TMP_DIR/$name.stderr"
  test ! -s "$TMP_DIR/$name.stdout"
}

run_fault faults/selector-drift.mjs DOM_SELECTION_DRIFT_MISSING_ROOT selector
run_fault faults/attribute-property.mjs ATTRIBUTE_PROPERTY_BOOLEAN_DRIFT property
run_fault faults/unsafe-inner-html.mjs UNSAFE_INNER_HTML_CREATED_NODE injection
run_fault faults/semantic-breakage.mjs SEMANTIC_DOM_BREAKAGE_UL_CHILD semantic

echo "PASS dom-mutation lab baseline=0 faults=4 simulator=happy-dom@17.6.3"
