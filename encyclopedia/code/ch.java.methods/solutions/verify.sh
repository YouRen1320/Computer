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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java
java -cp "$CLASSES_DIR" WorkOrderMethodsChallenge > "$BUILD_DIR/solution.out"
java -ea -cp "$CLASSES_DIR" WorkOrderMethodsOracle > "$BUILD_DIR/oracle.out"
[[ "$(cat "$BUILD_DIR/solution.out")" == $'total=5997\nremaining=7\nfirst=5\ncountdown=4' ]]
grep -Fqx "assertions=8 passed" "$BUILD_DIR/oracle.out"
cat "$BUILD_DIR/solution.out"
cat "$BUILD_DIR/oracle.out"
echo "PRIVATE SOLUTION PASS methods=4 assertions=8 javac=$JAVAC_VERSION"
