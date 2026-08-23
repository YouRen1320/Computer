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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/EnumRecordSealedDemo.java"
java -cp "$CLASSES_DIR" EnumRecordSealedDemo > "$BUILD_DIR/demo.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
status=IN_PROGRESS
terminal.closed=true
coordinate=EquipmentCoordinate[site=NC-1, aisle=3, slot=7]
coordinate.equal=true
command.assign=ASSIGN|WO-1001|TECH-07
command.start=START|WO-1001|TECH-07
command.close=CLOSE|WO-1001|bearing replaced
assertions=14 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

cp "$ROOT_DIR/failures/NonExhaustiveCommandFailure.java.txt" "$BUILD_DIR/failure-src/NonExhaustiveCommandFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/NonExhaustiveCommandFailure.java" > "$BUILD_DIR/exhaustive.out" 2> "$BUILD_DIR/exhaustive.err"
exhaustive_status=$?
javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR/failures/UnknownStatusFailure.java" "$ROOT_DIR/failures/RecordArrayEqualityFailure.java" > "$BUILD_DIR/failures-compile.out" 2> "$BUILD_DIR/failures-compile.err"
failure_compile_status=$?
java -cp "$FAILURE_CLASSES" UnknownStatusFailure > "$BUILD_DIR/status.out" 2> "$BUILD_DIR/status.err"
status_status=$?
java -cp "$FAILURE_CLASSES" RecordArrayEqualityFailure > "$BUILD_DIR/array.out" 2> "$BUILD_DIR/array.err"
array_status=$?
set -e
[[ $exhaustive_status -ne 0 ]]
[[ $failure_compile_status -eq 0 ]]
[[ $status_status -eq 4 ]]
[[ $array_status -eq 5 ]]
grep -Fq "compiler.err.not.exhaustive" "$BUILD_DIR/exhaustive.err"
grep -Fqx "STRING_STATUS_FAILURE input=IN_PROGRES exception=IllegalArgumentException" "$BUILD_DIR/status.err"
grep -Fqx "RECORD_ARRAY_EQUALITY_BROKEN sameContents=true recordEquals=false" "$BUILD_DIR/array.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_COMPILE_FAILURE NonExhaustiveCommandFailure status=$exhaustive_status evidence=new-permitted-type"
echo "EXPECTED_FAILURE UnknownStatusFailure status=$status_status evidence=string-typo"
echo "EXPECTED_FAILURE RecordArrayEqualityFailure status=$array_status evidence=array-component"
echo "EXAMPLE PASS assertions=14 expected_failures=3 java=$JAVA_VERSION"
