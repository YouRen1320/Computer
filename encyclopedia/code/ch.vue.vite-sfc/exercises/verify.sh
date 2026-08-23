#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

set +e
node "$ROOT/scripts/check-entry.mjs" >"$TMP_DIR/out" 2>"$TMP_DIR/err"
status=$?
set -e

if [[ $status -eq 0 ]]; then
  if ! grep -Fq 'ENTRY_CONTRACT_OK' "$TMP_DIR/out"; then
    cat "$TMP_DIR/out" >&2
    echo "SOLVED OUTPUT MARKER MISMATCH" >&2
    exit 42
  fi
  echo "EXERCISE PASS mount-contract=matched"
elif [[ $status -eq 8 ]]; then
  if ! grep -Fq 'EXPECTED_FACTORYCARE_MOUNT_FAILURE host=#factorycare-root selector=#app' "$TMP_DIR/err"; then
    cat "$TMP_DIR/err" >&2
    echo "STARTER FAILURE MARKER MISMATCH status=8" >&2
    exit 43
  fi
  echo "EXPECTED_RED status=8 reason=entry-mount-selector-mismatch"
  exit 41
else
  cat "$TMP_DIR/err" >&2
  echo "STARTER FAILURE STATUS MISMATCH expected=8 actual=$status" >&2
  exit 44
fi
