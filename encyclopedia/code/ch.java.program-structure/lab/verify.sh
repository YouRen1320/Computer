#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$ROOT_DIR/../../.." && pwd)"

"$WORKSPACE/examples/encyclopedia/ch.java.program-structure/verify.sh"
"$ROOT_DIR/verify-failures.sh"

echo "LAB_GREEN: positive program structure and four isolated compiler failures are verified."
