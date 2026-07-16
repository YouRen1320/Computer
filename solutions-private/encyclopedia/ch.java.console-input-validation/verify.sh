#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C LANG=C
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/RepairIntakeSolution.java" "$ROOT_DIR/src/RepairIntakeOracle.java"
java -cp "$CLASSES_DIR" RepairIntakeOracle > "$BUILD_DIR/oracle.out"
grep -Fqx "assertions=7 passed" "$BUILD_DIR/oracle.out"
cat "$BUILD_DIR/oracle.out"
echo "SOLUTION PASS console-input assertions=7"
