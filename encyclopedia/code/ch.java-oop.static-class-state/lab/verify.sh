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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/com/factorycare/workorder/StaticStateLab.java"
java -cp "$CLASSES_DIR" com.factorycare.workorder.StaticStateLab > "$BUILD_DIR/lab.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
nc=NC-0001,NC-0002
nj=NJ-0001
factory=PUMP|CREATED
lab.assertions=14 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"

cp "$ROOT_DIR/failures/InstanceRuleAsStaticFailure.java.txt" "$BUILD_DIR/failure-src/InstanceRuleAsStaticFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/InstanceRuleAsStaticFailure.java" > "$BUILD_DIR/static.out" 2> "$BUILD_DIR/static.err"
static_status=$?
javac --release 25 -d "$BUILD_DIR/failure-classes" "$ROOT_DIR/failures/SharedSequenceFailure.java" > "$BUILD_DIR/shared-compile.out" 2> "$BUILD_DIR/shared-compile.err"
shared_compile_status=$?
java -cp "$BUILD_DIR/failure-classes" SharedSequenceFailure > "$BUILD_DIR/shared.out" 2> "$BUILD_DIR/shared.err"
shared_status=$?
set -e
[[ $static_status -ne 0 ]]
[[ $shared_compile_status -eq 0 ]]
[[ $shared_status -ne 0 ]]
grep -Fq "compiler.err.non-static.cant.be.ref" "$BUILD_DIR/static.err"
grep -Fqx "SHARED_SEQUENCE expected=NC-0001 actual=NC-0002" "$BUILD_DIR/shared.err"

cat "$BUILD_DIR/lab.out"
echo "EXPECTED_COMPILE_FAILURE InstanceRuleAsStaticFailure status=$static_status evidence=static-context"
echo "EXPECTED_FAILURE SharedSequenceFailure status=$shared_status evidence=test-order"
echo "LAB PASS assertions=14 expected_failures=2 java=$JAVA_VERSION"
