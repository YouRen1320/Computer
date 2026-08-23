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
javac --release 25 -d "$CLASSES_DIR" \
  "$ROOT_DIR/src/com/factorycare/money/domain/Money.java" \
  "$ROOT_DIR/src/com/factorycare/money/domain/MaintenanceWindow.java" \
  "$ROOT_DIR/src/com/factorycare/money/app/MoneyLab.java"
java -cp "$CLASSES_DIR" com.factorycare.money.app.MoneyLab > "$BUILD_DIR/lab.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
base=5000|CNY
total=5750|CNY
hours=8,10
lab.assertions=16 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"

cp "$ROOT_DIR/failures/FinalFieldReassignmentFailure.java.txt" "$BUILD_DIR/failure-src/FinalFieldReassignmentFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/FinalFieldReassignmentFailure.java" > "$BUILD_DIR/final.out" 2> "$BUILD_DIR/final.err"
final_status=$?
javac --release 25 -d "$BUILD_DIR/failure-classes" "$ROOT_DIR/failures/MutableMoneyFailure.java" "$ROOT_DIR/failures/LeakyWindowFailure.java" > "$BUILD_DIR/runtime-compile.out" 2> "$BUILD_DIR/runtime-compile.err"
runtime_compile_status=$?
java -cp "$BUILD_DIR/failure-classes" MutableMoneyFailure > "$BUILD_DIR/mutable.out" 2> "$BUILD_DIR/mutable.err"
mutable_status=$?
java -cp "$BUILD_DIR/failure-classes" LeakyWindowFailure > "$BUILD_DIR/leak.out" 2> "$BUILD_DIR/leak.err"
leak_status=$?
set -e
[[ $final_status -ne 0 ]]
[[ $runtime_compile_status -eq 0 ]]
[[ $mutable_status -ne 0 ]]
[[ $leak_status -ne 0 ]]
grep -Fq "compiler.err.cant.assign.val.to.var: final," "$BUILD_DIR/final.err"
grep -Fqx "IMMUTABILITY_BROKEN expectedOriginal=5000 actualOriginal=5750 result=5750" "$BUILD_DIR/mutable.err"
grep -Fqx "OUTPUT_ALIAS_BROKEN expected=10 actual=0" "$BUILD_DIR/leak.err"

cat "$BUILD_DIR/lab.out"
echo "EXPECTED_COMPILE_FAILURE FinalFieldReassignmentFailure status=$final_status evidence=final-field"
echo "EXPECTED_FAILURE MutableMoneyFailure status=$mutable_status evidence=old-value-changed"
echo "EXPECTED_FAILURE LeakyWindowFailure status=$leak_status evidence=output-alias"
echo "LAB PASS assertions=16 expected_failures=3 java=$JAVA_VERSION"
