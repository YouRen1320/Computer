#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/BusinessValueChallenge.java" "$ROOT_DIR/failures/LooseRegexFailure.java"
set +e
java -cp "$CLASSES_DIR" BusinessValueChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"; challenge_status=$?
java -cp "$CLASSES_DIR" LooseRegexFailure > "$BUILD_DIR/regex.out" 2> "$BUILD_DIR/regex.err"; regex_status=$?
set -e
[[ $challenge_status -eq 8 && $regex_status -eq 7 ]]
grep -Fqx "STARTER_DOUBLE_MONEY expected=0.1 actual=0.1000000000000000055511151231257827021181583404541015625" "$BUILD_DIR/challenge.err"
grep -Fqx "LOOSE_REGEX_ACCEPTED input=WO- expected=false actual=true" "$BUILD_DIR/regex.err"

echo "STARTER EXPECTED FAILURE status=$challenge_status reason=double-money-input"
echo "EXPECTED_FAILURE LooseRegexFailure status=$regex_status evidence=invalid-id-accepted"
echo "EXERCISE CHECK PASS expected_failures=2 java=$JAVA_VERSION"
