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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/ExceptionContractChallenge.java" "$ROOT_DIR/failures/SwallowedFailure.java"
set +e
java -cp "$CLASSES_DIR" ExceptionContractChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"; challenge_status=$?
java -cp "$CLASSES_DIR" SwallowedFailure > "$BUILD_DIR/swallow.out" 2> "$BUILD_DIR/swallow.err"; swallow_status=$?
set -e
[[ $challenge_status -eq 8 && $swallow_status -eq 4 ]]
grep -Fqx "STARTER_INPUT_MISCLASSIFIED expected=INVALID_INPUT actual=SYSTEM_ERROR:cause=missing" "$BUILD_DIR/challenge.err"
grep -Fqx "SWALLOWED_FAILURE result=null causeLost=true" "$BUILD_DIR/swallow.err"

cp "$ROOT_DIR/failures/UnhandledCheckedFailure.java.txt" "$BUILD_DIR/failure-src/UnhandledCheckedFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/UnhandledCheckedFailure.java" > "$BUILD_DIR/checked.out" 2> "$BUILD_DIR/checked.err"; checked_status=$?
set -e
[[ $checked_status -ne 0 ]]
grep -Fq "compiler.err.unreported.exception.need.to.catch.or.throw" "$BUILD_DIR/checked.err"

echo "STARTER EXPECTED FAILURE status=$challenge_status reason=input-misclassified"
echo "EXPECTED_FAILURE SwallowedFailure status=$swallow_status evidence=empty-catch-null"
echo "EXPECTED_COMPILE_FAILURE UnhandledCheckedFailure status=$checked_status evidence=catch-or-declare"
echo "EXERCISE CHECK PASS expected_failures=3 java=$JAVA_VERSION"
