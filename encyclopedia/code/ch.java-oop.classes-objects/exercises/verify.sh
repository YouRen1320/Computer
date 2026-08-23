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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/DeviceClassChallenge.java"
set +e
java -cp "$CLASSES_DIR" DeviceClassChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"
status=$?
set -e
if [[ $status -eq 0 ]]; then
  grep -Fqx "exercise.assertions=10 passed" "$BUILD_DIR/challenge.out"
  echo "EXERCISE PASS assertions=10 java=$JAVA_VERSION"
else
  grep -Fq "CHALLENGE_FAILURE" "$BUILD_DIR/challenge.err"
  echo "STARTER EXPECTED FAILURE status=$status; complete TODO 1..3"
  printf '%s\n' 'EXPECTED_RED chapter=ch.java-oop.classes-objects oracle=verified-starter-failure'
  exit 41
fi
