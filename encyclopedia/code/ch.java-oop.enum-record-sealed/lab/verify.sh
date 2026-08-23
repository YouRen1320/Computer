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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/EnumRecordSealedLab.java"
java -cp "$CLASSES_DIR" EnumRecordSealedLab > "$BUILD_DIR/lab.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
status.count=12
terminal=CLOSED,CANCELLED
coordinate=EquipmentCoordinate[site=NC-FACTORY, aisle=2, slot=9]
command.assign=ASSIGN|WO-2001|TECH-09
command.start=START|WO-2001|TECH-09
command.resolve=RESOLVE|WO-2001|seal replaced
assertions=17 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"

cp "$ROOT_DIR/failures/NonExhaustiveCommandFailure.java.txt" "$BUILD_DIR/failure-src/NonExhaustiveCommandFailure.java"
cp "$ROOT_DIR/failures/UnauthorizedSubtypeFailure.java.txt" "$BUILD_DIR/failure-src/UnauthorizedSubtypeFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/NonExhaustiveCommandFailure.java" > "$BUILD_DIR/exhaustive.out" 2> "$BUILD_DIR/exhaustive.err"
exhaustive_status=$?
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/UnauthorizedSubtypeFailure.java" > "$BUILD_DIR/permits.out" 2> "$BUILD_DIR/permits.err"
permits_status=$?
javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR/failures/UnknownStatusFailure.java" "$ROOT_DIR/failures/MutableRecordFailure.java" > "$BUILD_DIR/failures-compile.out" 2> "$BUILD_DIR/failures-compile.err"
failure_compile_status=$?
java -cp "$FAILURE_CLASSES" UnknownStatusFailure > "$BUILD_DIR/status.out" 2> "$BUILD_DIR/status.err"
status_status=$?
java -cp "$FAILURE_CLASSES" MutableRecordFailure > "$BUILD_DIR/record.out" 2> "$BUILD_DIR/record.err"
record_status=$?
set -e
[[ $exhaustive_status -ne 0 ]]
[[ $permits_status -ne 0 ]]
[[ $failure_compile_status -eq 0 ]]
[[ $status_status -eq 6 ]]
[[ $record_status -eq 7 ]]
grep -Fq "compiler.err.not.exhaustive" "$BUILD_DIR/exhaustive.err"
grep -Fq "compiler.err.cant.inherit.from.sealed" "$BUILD_DIR/permits.err"
grep -Fqx "LAB_UNKNOWN_STATUS input=CANCELED canonical=CANCELLED" "$BUILD_DIR/status.err"
grep -Fqx "LAB_RECORD_ALIAS_BROKEN expected=8 actual=99" "$BUILD_DIR/record.err"

cat "$BUILD_DIR/lab.out"
echo "EXPECTED_COMPILE_FAILURE NonExhaustiveCommandFailure status=$exhaustive_status evidence=request-approval-case"
echo "EXPECTED_COMPILE_FAILURE UnauthorizedSubtypeFailure status=$permits_status evidence=permits-boundary"
echo "EXPECTED_FAILURE UnknownStatusFailure status=$status_status evidence=canonical-spelling"
echo "EXPECTED_FAILURE MutableRecordFailure status=$record_status evidence=input-alias"
echo "LAB PASS assertions=17 expected_failures=4 java=$JAVA_VERSION"
