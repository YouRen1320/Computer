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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/DeviceIdChallenge.java"
set +e
java -cp "$CLASSES_DIR" DeviceIdChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"
challenge_status=$?
set -e
[[ $challenge_status -eq 8 ]]
grep -Fqx "STARTER_HASH_CONTRACT_FAILURE equal=true hashesEqual=false" "$BUILD_DIR/challenge.err"

cp "$ROOT_DIR/failures/InvalidOverrideFailure.java.txt" "$BUILD_DIR/failure-src/InvalidOverrideFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/InvalidOverrideFailure.java" > "$BUILD_DIR/override.out" 2> "$BUILD_DIR/override.err"
override_status=$?
set -e
[[ $override_status -ne 0 ]]
grep -Fq "compiler.err.method.does.not.override.superclass" "$BUILD_DIR/override.err"

echo "STARTER EXPECTED FAILURE status=$challenge_status reason=equals-hashCode-field-mismatch"
echo "EXPECTED_COMPILE_FAILURE InvalidOverrideFailure status=$override_status evidence=wrong-equals-signature"
echo "EXERCISE CHECK PASS expected_failures=2 java=$JAVA_VERSION"
exit 41
