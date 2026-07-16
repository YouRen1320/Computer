#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java "$ROOT_DIR"/failures/*.java

set +e
java -cp "$CLASSES_DIR" ThreadSafetyChallenge > "$BUILD_DIR/starter.out" 2> "$BUILD_DIR/starter.err"
starter_status=$?
set -e
[[ $starter_status -ne 0 ]]
grep -Fq 'COUNTER_CONTRACT' "$BUILD_DIR/starter.err"

set +e
java -cp "$CLASSES_DIR" DeterministicLostUpdateContractFailure \
    > "$BUILD_DIR/failure.out" 2> "$BUILD_DIR/failure.err"
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
grep -Fq 'LOST_UPDATE expected=2 actual=1' "$BUILD_DIR/failure.err"

printf 'STARTER EXPECTED FAILURE status=%s reason=COUNTER_CONTRACT; complete TODO 1..4\n' "$starter_status"
printf 'CONTRACT FAILURE REPRODUCED status=%s evidence=LOST_UPDATE\n' "$failure_status"
