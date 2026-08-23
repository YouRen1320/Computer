#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
FAILURE_CLASSES="$BUILD_DIR/failure-classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR" "$FAILURE_CLASSES" "$BUILD_DIR/failure-src"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/RestrictedTypesSolution.java"
java -cp "$CLASSES_DIR" RestrictedTypesSolution > "$BUILD_DIR/solution.out"
grep -Fqx "solution.assertions=14 passed" "$BUILD_DIR/solution.out"

cp "$ROOT_DIR/failures/NonExhaustiveCommandFailure.java.txt" "$BUILD_DIR/failure-src/NonExhaustiveCommandFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/NonExhaustiveCommandFailure.java" > "$BUILD_DIR/exhaustive.out" 2> "$BUILD_DIR/exhaustive.err"
exhaustive_status=$?
javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR/failures/UnknownStatusFailure.java" > "$BUILD_DIR/status-compile.out" 2> "$BUILD_DIR/status-compile.err"
status_compile_status=$?
java -cp "$FAILURE_CLASSES" UnknownStatusFailure > "$BUILD_DIR/status.out" 2> "$BUILD_DIR/status.err"
status_status=$?
set -e
[[ $exhaustive_status -ne 0 ]]
[[ $status_compile_status -eq 0 ]]
[[ $status_status -eq 9 ]]
grep -Fq "compiler.err.not.exhaustive" "$BUILD_DIR/exhaustive.err"
grep -Fqx "SOLUTION_STATUS_REPLAY input=CANCELED canonical=CANCELLED" "$BUILD_DIR/status.err"

cat "$BUILD_DIR/solution.out"
echo "EXPECTED_COMPILE_FAILURE NonExhaustiveCommandFailure status=$exhaustive_status evidence=cancel-case"
echo "EXPECTED_FAILURE UnknownStatusFailure status=$status_status evidence=canonical-spelling"
echo "SOLUTION PASS assertions=14 expected_failures=2 java=$JAVA_VERSION"
