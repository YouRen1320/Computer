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
  if ! grep -Fq 'STABLE_WORK_ORDER_KEY_OK expression=order.id node=beta' "$TMP_DIR/out"; then
    cat "$TMP_DIR/out" >&2
    echo "SOLVED OUTPUT MARKER MISMATCH" >&2
    exit 42
  fi
  echo "EXERCISE PASS identity=stable key=order.id"
elif [[ $status -eq 8 ]]; then
  if ! grep -Fq 'EXPECTED_STABLE_WORK_ORDER_KEY expression=index oldB=beta newB=alpha' "$TMP_DIR/err"; then
    cat "$TMP_DIR/err" >&2
    echo "STARTER FAILURE MARKER MISMATCH status=8" >&2
    exit 43
  fi
  echo "EXPECTED_RED status=8 reason=index-key-reuses-position-node"
  exit 41
else
  cat "$TMP_DIR/err" >&2
  echo "STARTER FAILURE STATUS MISMATCH expected=8 actual=$status" >&2
  exit 44
fi
