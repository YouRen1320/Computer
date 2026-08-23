#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
JAVAC_VERSION="$(javac -version 2>&1)"
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
javac --release 25 -Xlint:all -Werror \
    -d "$BUILD_DIR" \
    "$ROOT_DIR/src/DiagnosticsChallengeSolution.java"
java -cp "$BUILD_DIR" DiagnosticsChallengeSolution > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"

if rg -n 'TODO' "$ROOT_DIR/src" >/dev/null; then
    echo "SOLUTION STILL CONTAINS TODO" >&2
    exit 1
fi

cat "$BUILD_DIR/actual.out"
