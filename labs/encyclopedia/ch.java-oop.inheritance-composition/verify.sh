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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/InheritanceCompositionLab.java"
java -cp "$CLASSES_DIR" InheritanceCompositionLab > "$BUILD_DIR/lab.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
sms=SMS|WORK_ORDER|WO-1001|NORMAL
mail=MAIL|WORK_ORDER|WO-1001|NORMAL
recorded=RECORDED|WORK_ORDER|WO-1009|URGENT
replacement.independent=true
assertions=14 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"

cp "$ROOT_DIR/failures/SuperConstructorFailure.java.txt" "$BUILD_DIR/failure-src/SuperConstructorFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/SuperConstructorFailure.java" > "$BUILD_DIR/constructor.out" 2> "$BUILD_DIR/constructor.err"
constructor_status=$?
javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR/failures/BrokenPreconditionFailure.java" "$ROOT_DIR/failures/MissingSuperAuditFailure.java" > "$BUILD_DIR/failures-compile.out" 2> "$BUILD_DIR/failures-compile.err"
failure_compile_status=$?
java -cp "$FAILURE_CLASSES" BrokenPreconditionFailure > "$BUILD_DIR/precondition.out" 2> "$BUILD_DIR/precondition.err"
precondition_status=$?
java -cp "$FAILURE_CLASSES" MissingSuperAuditFailure > "$BUILD_DIR/audit.out" 2> "$BUILD_DIR/audit.err"
audit_status=$?
set -e
[[ $constructor_status -ne 0 ]]
[[ $failure_compile_status -eq 0 ]]
[[ $precondition_status -eq 6 ]]
[[ $audit_status -eq 7 ]]
grep -Fq "compiler.err.cant.apply.symbol" "$BUILD_DIR/constructor.err"
grep -Fqx "PARENT_CONTRACT_BROKEN input=NORMAL parent=accepted child=rejected" "$BUILD_DIR/precondition.err"
grep -Fqx "BASE_AUDIT_LOST expected=SMS|TENANT-A|AUDIT|WO-1001 actual=SMS|WO-1001" "$BUILD_DIR/audit.err"

cat "$BUILD_DIR/lab.out"
echo "EXPECTED_COMPILE_FAILURE SuperConstructorFailure status=$constructor_status evidence=missing-super-constructor"
echo "EXPECTED_FAILURE BrokenPreconditionFailure status=$precondition_status evidence=parent-contract"
echo "EXPECTED_FAILURE MissingSuperAuditFailure status=$audit_status evidence=missing-super"
echo "LAB PASS assertions=14 expected_failures=3 java=$JAVA_VERSION"
