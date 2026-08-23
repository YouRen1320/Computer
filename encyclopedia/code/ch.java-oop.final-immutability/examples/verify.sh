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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/FinalImmutabilityDemo.java"
java -cp "$CLASSES_DIR" FinalImmutabilityDemo > "$BUILD_DIR/demo.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
constant=CNY
reference.same=true
reference.value=2
base=5000
result=5750
baseAfter=5000
inputIsolated=8
outputIsolated=10
assertions=12 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

cp "$ROOT_DIR/failures/FinalReassignmentFailure.java.txt" "$BUILD_DIR/failure-src/FinalReassignmentFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/FinalReassignmentFailure.java" > "$BUILD_DIR/final.out" 2> "$BUILD_DIR/final.err"
final_status=$?
javac --release 25 -d "$BUILD_DIR/failure-classes" "$ROOT_DIR/failures/LeakyArrayFailure.java" > "$BUILD_DIR/leak-compile.out" 2> "$BUILD_DIR/leak-compile.err"
leak_compile_status=$?
java -cp "$BUILD_DIR/failure-classes" LeakyArrayFailure > "$BUILD_DIR/leak.out" 2> "$BUILD_DIR/leak.err"
leak_status=$?
set -e
[[ $final_status -ne 0 ]]
[[ $leak_compile_status -eq 0 ]]
[[ $leak_status -ne 0 ]]
grep -Fq "compiler.err.cant.assign.val.to.var: final," "$BUILD_DIR/final.err"
grep -Fqx "INPUT_ALIAS_BROKEN expected=8 actual=23" "$BUILD_DIR/leak.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_COMPILE_FAILURE FinalReassignmentFailure status=$final_status evidence=final-reassignment"
echo "EXPECTED_FAILURE LeakyArrayFailure status=$leak_status evidence=input-alias"
echo "EXAMPLE PASS assertions=12 expected_failures=2 java=$JAVA_VERSION"
