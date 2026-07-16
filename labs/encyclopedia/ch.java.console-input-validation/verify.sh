#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C LANG=C
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/InputBoundaryLab.java" "$ROOT_DIR/src/InputBoundaryOracle.java" "$ROOT_DIR/failures/EofRetryBug.java" "$ROOT_DIR/failures/EofRetryOracle.java"
java -cp "$CLASSES_DIR" InputBoundaryOracle > "$BUILD_DIR/oracle.out"
java -cp "$CLASSES_DIR" EofRetryOracle > "$BUILD_DIR/failure.out"
grep -Fqx "assertions=6 passed" "$BUILD_DIR/oracle.out"
grep -Fqx "EXPECTED_LOGIC_FAILURE eof-retry=true contract=must-terminate" "$BUILD_DIR/failure.out"
cat "$BUILD_DIR/oracle.out"
cat "$BUILD_DIR/failure.out"
echo "LAB PASS console-input assertions=6 eof=finite expected-failures=1"
