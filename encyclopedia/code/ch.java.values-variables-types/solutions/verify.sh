#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$ROOT_DIR/../../.." && pwd)"

"$WORKSPACE/labs/encyclopedia/ch.java.values-variables-types/verify.sh" "$ROOT_DIR/lab-solution"

echo "PRIVATE_GREEN: the private lab solution satisfies the public executable oracle."
