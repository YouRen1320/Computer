#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
actual="$(node "$ROOT/scripts/check-entry.mjs")"
[[ "$actual" == 'ENTRY_CONTRACT_OK host=#factorycare-root selector=#factorycare-root' ]]
echo "SOLUTION PASS mount-contract=matched"
