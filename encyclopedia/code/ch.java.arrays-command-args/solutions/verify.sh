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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/PriorityBatchChallenge.java"
java -cp "$CLASSES_DIR" PriorityBatchChallenge > "$BUILD_DIR/empty.out"
java -cp "$CLASSES_DIR" PriorityBatchChallenge 3 4 5 4 > "$BUILD_DIR/many.out"
[[ "$(cat "$BUILD_DIR/empty.out")" == $'count=0\nmax=NONE\nurgent=0\nfirst4=-1' ]]
[[ "$(cat "$BUILD_DIR/many.out")" == $'count=4\nmax=5\nurgent=3\nfirst4=1' ]]
cat "$BUILD_DIR/empty.out"
cat "$BUILD_DIR/many.out"
echo "PRIVATE SOLUTION PASS arrays=empty-and-many javac=$JAVAC_VERSION"
