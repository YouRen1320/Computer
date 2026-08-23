#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
JAVAC_VERSION="$(javac -version 2>&1)"

case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes" "$BUILD_DIR/failures"

javac --release 25 -Xlint:all -Werror \
    -d "$BUILD_DIR/classes" \
    "$ROOT_DIR/src/LoggingDiagnosticsExample.java"
javac --release 25 -Xlint:all -Werror \
    -cp "$BUILD_DIR/classes" \
    -d "$BUILD_DIR/failures" \
    "$ROOT_DIR/failures/MissingCorrelationFailure.java" \
    "$ROOT_DIR/failures/SensitiveFieldLeakFailure.java"

java -cp "$BUILD_DIR/classes" LoggingDiagnosticsExample > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"

run_expected_failure() {
    local class_name="$1"
    local marker="$2"
    local log_file="$BUILD_DIR/$class_name.log"
    if java -cp "$BUILD_DIR/classes:$BUILD_DIR/failures" "$class_name" > "$log_file" 2>&1; then
        echo "EXPECTED FAILURE: $class_name" >&2
        exit 1
    fi
    grep -Fq "$marker" "$log_file"
}

run_expected_failure MissingCorrelationFailure INVALID_CORRELATION_ID
run_expected_failure SensitiveFieldLeakFailure SENSITIVE_VALUE_LEAK

cat "$BUILD_DIR/actual.out"
