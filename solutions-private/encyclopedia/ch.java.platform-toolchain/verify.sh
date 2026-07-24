#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "$ROOT_DIR/../../.." && pwd)"
EXAMPLE_VERIFY="$WORKSPACE/examples/encyclopedia/ch.java.platform-toolchain/scripts/verify.sh"

"$EXAMPLE_VERIFY"
grep -Fq 'out/com/example/App.class' "$ROOT_DIR/README.md"
grep -Fq 'JVM 加载' "$ROOT_DIR/README.md"
grep -Fq '程序已运行' "$ROOT_DIR/README.md"

echo "PRIVATE_GREEN: runnable toolchain oracle and isolated explanations are consistent."
