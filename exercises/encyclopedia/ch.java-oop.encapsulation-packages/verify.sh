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
mkdir -p "$CLASSES_DIR" "$BUILD_DIR/failure-src"
find "$ROOT_DIR/src" -name '*.java' -print0 | xargs -0 javac --release 25 -d "$CLASSES_DIR"
java -cp "$CLASSES_DIR" com.factorycare.device.app.EncapsulationChallenge > "$BUILD_DIR/challenge.out"
grep -Fqx "challenge.assertions=8 passed" "$BUILD_DIR/challenge.out"

cp "$ROOT_DIR/failures/DirectStatusAccess.java.txt" "$BUILD_DIR/failure-src/DirectStatusAccess.java"
set +e
javac -XDrawDiagnostics --release 25 -cp "$CLASSES_DIR" -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/DirectStatusAccess.java" > "$BUILD_DIR/direct.out" 2> "$BUILD_DIR/direct.err"
direct_status=$?
set -e
if [[ $direct_status -eq 0 ]]; then
  echo "STARTER EXPECTED FAILURE reason=public-field-still-accessible; complete TODO"
else
  grep -Fq "compiler.err.report.access: status, private, com.factorycare.device.domain.Device" "$BUILD_DIR/direct.err"
  echo "EXERCISE PASS assertions=8 expected_compile_failures=1 java=$JAVA_VERSION"
fi
