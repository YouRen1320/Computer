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
    "$ROOT_DIR/src/DiagnosticsChallenge.java"

if java -cp "$BUILD_DIR" DiagnosticsChallenge > "$BUILD_DIR/starter.log" 2>&1; then
    echo "STARTER UNEXPECTEDLY PASSED: run the completed program directly" >&2
    exit 1
fi

grep -Fq 'SECRET_NOT_REDACTED' "$BUILD_DIR/starter.log"
test "$(rg -c 'TODO' "$ROOT_DIR/src/DiagnosticsChallenge.java")" -eq 4

printf 'starter=expected-failure first=SECRET_NOT_REDACTED todos=4\n'
printf 'EXERCISE READY jdk=25 mode=offline\n'
