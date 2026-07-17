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
  grep -Fq 'ENTRY_CONTRACT_OK' "$TMP_DIR/out"
  echo "EXERCISE PASS mount-contract=matched"
elif [[ $status -eq 8 ]]; then
  grep -Fq 'EXPECTED_FACTORYCARE_MOUNT_FAILURE host=#factorycare-root selector=#app' "$TMP_DIR/err"
  echo "STARTER EXPECTED FAILURE status=8 reason=entry-mount-selector-mismatch"
else
  cat "$TMP_DIR/err" >&2
  exit "$status"
fi
