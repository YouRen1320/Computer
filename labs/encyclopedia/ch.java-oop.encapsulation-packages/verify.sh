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
java -cp "$CLASSES_DIR" com.factorycare.workorder.app.WorkOrderLab > "$BUILD_DIR/lab.out"
java -cp "$CLASSES_DIR" com.factorycare.workorder.app.WorkOrderOracle > "$BUILD_DIR/oracle.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
created=WO-1001|CREATED
assigned=TECH-07|ASSIGNED
started=IN_PROGRESS
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"
grep -Fqx "assertions=12 passed" "$BUILD_DIR/oracle.out"

cp "$ROOT_DIR/failures/WrongImportFailure.java.txt" "$BUILD_DIR/failure-src/WrongImportFailure.java"
cp "$ROOT_DIR/failures/CrossPackagePolicyFailure.java.txt" "$BUILD_DIR/failure-src/CrossPackagePolicyFailure.java"
cp "$ROOT_DIR/failures/PrivateStatusFailure.java.txt" "$BUILD_DIR/failure-src/PrivateStatusFailure.java"
set +e
java -cp "$CLASSES_DIR" com.factorycare.workorder.app.LeakyFieldFailure > "$BUILD_DIR/leak.out" 2> "$BUILD_DIR/leak.err"
leak_status=$?
javac -XDrawDiagnostics --release 25 -cp "$CLASSES_DIR" -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/WrongImportFailure.java" > "$BUILD_DIR/import.out" 2> "$BUILD_DIR/import.err"
import_status=$?
javac -XDrawDiagnostics --release 25 -cp "$CLASSES_DIR" -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/CrossPackagePolicyFailure.java" > "$BUILD_DIR/policy.out" 2> "$BUILD_DIR/policy.err"
policy_status=$?
javac -XDrawDiagnostics --release 25 -cp "$CLASSES_DIR" -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/PrivateStatusFailure.java" > "$BUILD_DIR/private.out" 2> "$BUILD_DIR/private.err"
private_status=$?
set -e
[[ $leak_status -ne 0 ]]
[[ $import_status -ne 0 ]]
[[ $policy_status -ne 0 ]]
[[ $private_status -ne 0 ]]
grep -Fqx "PUBLIC_FIELD_LEAK expected=CREATED actual=UNKNOWN_FROM_UI" "$BUILD_DIR/leak.err"
grep -Fq "compiler.err.doesnt.exist: com.factorycare.workorders.domain" "$BUILD_DIR/import.err"
grep -Fq "compiler.err.not.def.public.cant.access: com.factorycare.workorder.domain.StatusPolicy" "$BUILD_DIR/policy.err"
grep -Fq "compiler.err.report.access: status, private, com.factorycare.workorder.domain.WorkOrder" "$BUILD_DIR/private.err"

cat "$BUILD_DIR/lab.out"
cat "$BUILD_DIR/oracle.out"
echo "EXPECTED_FAILURE LeakyFieldFailure status=$leak_status evidence=public-field-bypass"
echo "EXPECTED_COMPILE_FAILURE WrongImportFailure status=$import_status evidence=package-does-not-exist"
echo "EXPECTED_COMPILE_FAILURE CrossPackagePolicyFailure status=$policy_status evidence=package-private-access"
echo "EXPECTED_COMPILE_FAILURE PrivateStatusFailure status=$private_status evidence=private-field-access"
echo "LAB PASS assertions=12 expected_failures=4 java=$JAVA_VERSION"
