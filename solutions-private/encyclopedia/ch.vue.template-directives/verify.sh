#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
actual="$(node "$ROOT/scripts/check-key.mjs")"
[[ "$actual" == 'STABLE_WORK_ORDER_KEY_OK expression=order.id node=beta' ]]
echo "SOLUTION PASS identity=stable key=order.id"
