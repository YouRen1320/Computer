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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/RestrictedTypesChallenge.java"
set +e
java -cp "$CLASSES_DIR" RestrictedTypesChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"
challenge_status=$?
cp "$ROOT_DIR/failures/NonExhaustiveCommandFailure.java.txt" "$BUILD_DIR/failure-src/NonExhaustiveCommandFailure.java"
javac -XDrawDiagnostics --release 25 -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/NonExhaustiveCommandFailure.java" > "$BUILD_DIR/exhaustive.out" 2> "$BUILD_DIR/exhaustive.err"
exhaustive_status=$?
set -e
[[ $exhaustive_status -ne 0 ]]
grep -Fq "compiler.err.not.exhaustive" "$BUILD_DIR/exhaustive.err"
if [[ $challenge_status -eq 0 ]]; then
  grep -Fqx "challenge.assertions=14 passed" "$BUILD_DIR/challenge.out"
  cat "$BUILD_DIR/challenge.out"
  echo "EXERCISE PASS assertions=14 expected_compile_failures=1 java=$JAVA_VERSION"
else
  [[ $challenge_status -eq 8 ]]
  grep -Fqx "STARTER_EXHAUSTIVENESS_FAILURE command=CloseCommand actual=UNSUPPORTED" "$BUILD_DIR/challenge.err"
  echo "STARTER EXPECTED FAILURE status=$challenge_status reason=default-hides-close-command"
  printf '%s\n' 'EXPECTED_RED chapter=ch.java-oop.enum-record-sealed oracle=verified-starter-failure'
  exit 41
fi
