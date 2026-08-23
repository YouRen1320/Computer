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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/StaticStateChallenge.java"
set +e
java -cp "$CLASSES_DIR" StaticStateChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"
challenge_status=$?
set -e

cp "$ROOT_DIR/failures/StaticReadsInstanceFailure.java.txt" "$BUILD_DIR/failure-src/StaticReadsInstanceFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/StaticReadsInstanceFailure.java" > "$BUILD_DIR/static.out" 2> "$BUILD_DIR/static.err"
static_status=$?
set -e
[[ $static_status -ne 0 ]]
grep -Fq "compiler.err.non-static.cant.be.ref" "$BUILD_DIR/static.err"

if [[ $challenge_status -ne 0 ]]; then
  grep -Fqx "STARTER_ORDER_DEPENDENCY expected=WO-0001 actual=WO-0002" "$BUILD_DIR/challenge.err"
  echo "EXPECTED_COMPILE_FAILURE StaticReadsInstanceFailure status=$static_status evidence=static-context"
  echo "STARTER EXPECTED FAILURE status=$challenge_status reason=shared-static-sequence"
  printf '%s\n' 'EXPECTED_RED chapter=ch.java-oop.static-class-state oracle=verified-starter-failure'
  exit 41
fi

grep -Fqx "exercise.assertions=8 passed" "$BUILD_DIR/challenge.out"
cat "$BUILD_DIR/challenge.out"
echo "EXPECTED_COMPILE_FAILURE StaticReadsInstanceFailure status=$static_status evidence=static-context"
echo "EXERCISE PASS assertions=8 expected_compile_failures=1 java=$JAVA_VERSION"
