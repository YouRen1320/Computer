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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/NotificationReuseSolution.java"
java -cp "$CLASSES_DIR" NotificationReuseSolution > "$BUILD_DIR/solution.out"
grep -Fqx "solution.assertions=10 passed" "$BUILD_DIR/solution.out"

cp "$ROOT_DIR/failures/OverrideTypoFailure.java.txt" "$BUILD_DIR/failure-src/OverrideTypoFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/OverrideTypoFailure.java" > "$BUILD_DIR/override.out" 2> "$BUILD_DIR/override.err"
override_status=$?
javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR/failures/StrongerPreconditionFailure.java" > "$BUILD_DIR/fault-compile.out" 2> "$BUILD_DIR/fault-compile.err"
fault_compile_status=$?
java -cp "$FAILURE_CLASSES" StrongerPreconditionFailure > "$BUILD_DIR/fault.out" 2> "$BUILD_DIR/fault.err"
fault_status=$?
set -e
[[ $override_status -ne 0 ]]
[[ $fault_compile_status -eq 0 ]]
[[ $fault_status -eq 9 ]]
grep -Fq "compiler.err.method.does.not.override.superclass" "$BUILD_DIR/override.err"
grep -Fqx "SOLUTION_FAULT_REPLAY input=NORMAL parent=accepted child=rejected" "$BUILD_DIR/fault.err"

cat "$BUILD_DIR/solution.out"
echo "EXPECTED_COMPILE_FAILURE OverrideTypoFailure status=$override_status evidence=override-intent"
echo "EXPECTED_FAILURE StrongerPreconditionFailure status=$fault_status evidence=substitution"
echo "SOLUTION PASS assertions=10 expected_failures=2 java=$JAVA_VERSION"
