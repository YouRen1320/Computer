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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/InheritanceCompositionDemo.java"
java -cp "$CLASSES_DIR" InheritanceCompositionDemo > "$BUILD_DIR/demo.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
inheritance=SMS|NOTICE|WO-1001|bearing-high-temperature
parentUse=SMS|NOTICE|WO-1001|bearing-high-temperature
composition.sms=SMS|NOTICE|WO-1002|lubrication-due
composition.mail=MAIL|NOTICE|WO-1002|lubrication-due
dependency.changed=true
assertions=8 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

cp "$ROOT_DIR/failures/OverrideTypoFailure.java.txt" "$BUILD_DIR/failure-src/OverrideTypoFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/OverrideTypoFailure.java" > "$BUILD_DIR/override.out" 2> "$BUILD_DIR/override.err"
override_status=$?
javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR/failures/StrongerPreconditionFailure.java" "$ROOT_DIR/failures/MissingSuperFailure.java" > "$BUILD_DIR/failures-compile.out" 2> "$BUILD_DIR/failures-compile.err"
failure_compile_status=$?
java -cp "$FAILURE_CLASSES" StrongerPreconditionFailure > "$BUILD_DIR/precondition.out" 2> "$BUILD_DIR/precondition.err"
precondition_status=$?
java -cp "$FAILURE_CLASSES" MissingSuperFailure > "$BUILD_DIR/super.out" 2> "$BUILD_DIR/super.err"
super_status=$?
set -e
[[ $override_status -ne 0 ]]
[[ $failure_compile_status -eq 0 ]]
[[ $precondition_status -eq 4 ]]
[[ $super_status -eq 5 ]]
grep -Fq "compiler.err.method.does.not.override.superclass" "$BUILD_DIR/override.err"
grep -Fqx "SUBSTITUTION_BROKEN input=WO-1 parent=accepted child=rejected" "$BUILD_DIR/precondition.err"
grep -Fqx "SUPER_CALL_MISSING expected=SMS|AUDIT|WO-1001 actual=SMS|WO-1001" "$BUILD_DIR/super.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_COMPILE_FAILURE OverrideTypoFailure status=$override_status evidence=override-intent"
echo "EXPECTED_FAILURE StrongerPreconditionFailure status=$precondition_status evidence=stronger-precondition"
echo "EXPECTED_FAILURE MissingSuperFailure status=$super_status evidence=base-audit-omitted"
echo "EXAMPLE PASS assertions=8 expected_failures=3 java=$JAVA_VERSION"
