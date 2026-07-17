#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

set +e
node "$ROOT/scripts/check-key.mjs" >"$TMP_DIR/out" 2>"$TMP_DIR/err"
status=$?
set -e

if [[ $status -eq 0 ]]; then
  grep -Fq 'STABLE_WORK_ORDER_KEY_OK expression=order.id node=beta' "$TMP_DIR/out"
  echo "EXERCISE PASS identity=stable key=order.id"
elif [[ $status -eq 8 ]]; then
  grep -Fq 'EXPECTED_STABLE_WORK_ORDER_KEY expression=index oldB=beta newB=alpha' "$TMP_DIR/err"
  echo "STARTER EXPECTED FAILURE status=8 reason=index-key-reuses-position-node"
else
  cat "$TMP_DIR/err" >&2
  exit "$status"
fi
