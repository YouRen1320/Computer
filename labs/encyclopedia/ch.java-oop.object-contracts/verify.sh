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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/ObjectContractsLab.java"
java -cp "$CLASSES_DIR" ObjectContractsLab > "$BUILD_DIR/lab.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
report.equals=INPUT two normalized DeviceId values | OP equals | RESULT true
report.hash=INPUT two equal DeviceId values | OP hashCode equality | RESULT true
report.text=INPUT one DeviceId | OP toString | RESULT DeviceId[tenant=<redacted>, value=DEV-001]
identityEqual=false
valueEqual=true
otherTenantEqual=false
assertions=20 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"

cp "$ROOT_DIR/failures/InvalidOverrideFailure.java.txt" "$BUILD_DIR/failure-src/InvalidOverrideFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/InvalidOverrideFailure.java" > "$BUILD_DIR/override.out" 2> "$BUILD_DIR/override.err"
override_status=$?
javac --release 25 -d "$FAILURE_CLASSES" \
  "$ROOT_DIR/failures/HashFieldMismatchFailure.java" \
  "$ROOT_DIR/failures/ToStringLeakFailure.java" \
  "$ROOT_DIR/failures/SymmetryFailure.java" \
  "$ROOT_DIR/failures/NullUnsafeEqualsFailure.java" > "$BUILD_DIR/failures-compile.out" 2> "$BUILD_DIR/failures-compile.err"
failure_compile_status=$?
java -cp "$FAILURE_CLASSES" HashFieldMismatchFailure > "$BUILD_DIR/hash.out" 2> "$BUILD_DIR/hash.err"
hash_status=$?
java -cp "$FAILURE_CLASSES" ToStringLeakFailure > "$BUILD_DIR/leak.out" 2> "$BUILD_DIR/leak.err"
leak_status=$?
java -cp "$FAILURE_CLASSES" SymmetryFailure > "$BUILD_DIR/symmetry.out" 2> "$BUILD_DIR/symmetry.err"
symmetry_status=$?
java -cp "$FAILURE_CLASSES" NullUnsafeEqualsFailure > "$BUILD_DIR/null.out" 2> "$BUILD_DIR/null.err"
null_status=$?
set -e
[[ $override_status -ne 0 ]]
[[ $failure_compile_status -eq 0 ]]
[[ $hash_status -eq 4 ]]
[[ $leak_status -eq 5 ]]
[[ $symmetry_status -eq 6 ]]
[[ $null_status -eq 7 ]]
grep -Fq "compiler.err.method.does.not.override.superclass" "$BUILD_DIR/override.err"
grep -Fqx "HASH_CONTRACT_BROKEN equal=true hashesEqual=false" "$BUILD_DIR/hash.err"
grep -Fqx "TOSTRING_LEAK field=provisioningSecret canaryDetected=true" "$BUILD_DIR/leak.err"
grep -Fqx "EQUALS_SYMMETRY_BROKEN baseToChild=true childToBase=false" "$BUILD_DIR/symmetry.err"
grep -Fqx "EQUALS_NULL_BROKEN exception=NullPointerException" "$BUILD_DIR/null.err"

cat "$BUILD_DIR/lab.out"
echo "EXPECTED_COMPILE_FAILURE InvalidOverrideFailure status=$override_status evidence=wrong-equals-signature"
echo "EXPECTED_FAILURE HashFieldMismatchFailure status=$hash_status evidence=field-set-mismatch"
echo "EXPECTED_FAILURE ToStringLeakFailure status=$leak_status evidence=canary-detected"
echo "EXPECTED_FAILURE SymmetryFailure status=$symmetry_status evidence=inheritance-asymmetry"
echo "EXPECTED_FAILURE NullUnsafeEqualsFailure status=$null_status evidence=null-unsafe-cast"
echo "LAB PASS assertions=20 expected_failures=5 java=$JAVA_VERSION"
