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
mkdir -p "$CLASSES_DIR" "$BUILD_DIR/failure-src"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java
java -cp "$CLASSES_DIR" DeviceConstructionLab > "$BUILD_DIR/lab.out"
java -cp "$CLASSES_DIR" ConstructionOracle > "$BUILD_DIR/oracle.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
pump=PUMP-01|北区循环泵|REGISTERED
valve=VALVE-02|供水阀|IDLE
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"
grep -Fqx "assertions=13 passed" "$BUILD_DIR/oracle.out"

set +e
java -cp "$CLASSES_DIR" LateValidationFailure > "$BUILD_DIR/late.out" 2> "$BUILD_DIR/late.err"
late_status=$?
cp "$ROOT_DIR/RecursiveConstructorFailure.java.txt" "$BUILD_DIR/failure-src/RecursiveConstructorFailure.java"
javac -XDrawDiagnostics --release 25 -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/RecursiveConstructorFailure.java" > "$BUILD_DIR/recursive.out" 2> "$BUILD_DIR/recursive.err"
recursive_status=$?
set -e
[[ $late_status -ne 0 ]]
[[ $recursive_status -ne 0 ]]
grep -Fqx "LATE_VALIDATION leaked_code=<blank> published=true" "$BUILD_DIR/late.err"
grep -Fq "compiler.err.recursive.ctor.invocation" "$BUILD_DIR/recursive.err"

cat "$BUILD_DIR/lab.out"
cat "$BUILD_DIR/oracle.out"
echo "EXPECTED_FAILURE LateValidationFailure status=$late_status evidence=published-half-object"
echo "EXPECTED_COMPILE_FAILURE RecursiveConstructorFailure status=$recursive_status evidence=recursive-constructor-invocation"
echo "LAB PASS assertions=13 expected_failures=2 java=$JAVA_VERSION"
