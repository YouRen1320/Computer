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
mkdir -p "$CLASSES_DIR" "$BUILD_DIR/failure-src" "$BUILD_DIR/failure-classes"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/NotificationReuseChallenge.java"
set +e
java -cp "$CLASSES_DIR" NotificationReuseChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"
challenge_status=$?
cp "$ROOT_DIR/failures/OverrideTypoFailure.java.txt" "$BUILD_DIR/failure-src/OverrideTypoFailure.java"
javac -XDrawDiagnostics --release 25 -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/OverrideTypoFailure.java" > "$BUILD_DIR/override.out" 2> "$BUILD_DIR/override.err"
override_status=$?
set -e
[[ $override_status -ne 0 ]]
grep -Fq "compiler.err.method.does.not.override.superclass" "$BUILD_DIR/override.err"
if [[ $challenge_status -eq 0 ]]; then
  grep -Fqx "challenge.assertions=10 passed" "$BUILD_DIR/challenge.out"
  cat "$BUILD_DIR/challenge.out"
  echo "EXERCISE PASS assertions=10 expected_compile_failures=1 java=$JAVA_VERSION"
else
  [[ $challenge_status -eq 8 ]]
  grep -Fqx "STARTER_SUBSTITUTION_FAILURE input=NORMAL parent=accepted child=rejected" "$BUILD_DIR/challenge.err"
  echo "STARTER EXPECTED FAILURE status=$challenge_status reason=stronger-precondition-and-fake-is-a"
  printf '%s\n' 'EXPECTED_RED chapter=ch.java-oop.inheritance-composition oracle=verified-starter-failure'
  exit 41
fi
