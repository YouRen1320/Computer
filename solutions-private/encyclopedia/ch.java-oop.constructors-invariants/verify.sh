#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/ConstructorChallenge.java"
java -cp "$CLASSES_DIR" ConstructorChallenge > "$BUILD_DIR/solution.out"
grep -Fqx "challenge.assertions=10 passed" "$BUILD_DIR/solution.out"
[[ "$(wc -l < "$BUILD_DIR/solution.out" | tr -d '[:space:]')" == "1" ]]
cat "$BUILD_DIR/solution.out"
echo "PRIVATE SOLUTION PASS assertions=10 javac=$JAVAC_VERSION java=$JAVA_VERSION"
