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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/DeviceIdSolution.java"
java -cp "$CLASSES_DIR" DeviceIdSolution > "$BUILD_DIR/solution.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
solution.report=INPUT two equal DeviceId values | OP equals/hashCode | RESULT equals=true, hashesEqual=true
solution.text=DeviceId[tenant=<redacted>, value=DEV-001]
solution.assertions=16 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/solution.out"

cp "$ROOT_DIR/failures/InvalidOverrideFailure.java.txt" "$BUILD_DIR/failure-src/InvalidOverrideFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/InvalidOverrideFailure.java" > "$BUILD_DIR/override.out" 2> "$BUILD_DIR/override.err"
override_status=$?
javac --release 25 -d "$FAILURE_CLASSES" \
  "$ROOT_DIR/failures/HashFieldMismatchFailure.java" \
  "$ROOT_DIR/failures/ToStringLeakFailure.java" \
  "$ROOT_DIR/failures/EqualsOverloadFailure.java" > "$BUILD_DIR/failures-compile.out" 2> "$BUILD_DIR/failures-compile.err"
failure_compile_status=$?
java -cp "$FAILURE_CLASSES" HashFieldMismatchFailure > "$BUILD_DIR/hash.out" 2> "$BUILD_DIR/hash.err"
hash_status=$?
java -cp "$FAILURE_CLASSES" ToStringLeakFailure > "$BUILD_DIR/leak.out" 2> "$BUILD_DIR/leak.err"
leak_status=$?
java -cp "$FAILURE_CLASSES" EqualsOverloadFailure > "$BUILD_DIR/overload.out" 2> "$BUILD_DIR/overload.err"
overload_status=$?
set -e
[[ $override_status -ne 0 ]]
[[ $failure_compile_status -eq 0 ]]
[[ $hash_status -eq 4 ]]
[[ $leak_status -eq 5 ]]
[[ $overload_status -eq 6 ]]
grep -Fq "compiler.err.method.does.not.override.superclass" "$BUILD_DIR/override.err"
grep -Fqx "HASH_CONTRACT_BROKEN equal=true hashesEqual=false" "$BUILD_DIR/hash.err"
grep -Fqx "TOSTRING_LEAK field=secret canaryDetected=true" "$BUILD_DIR/leak.err"
grep -Fqx "EQUALS_OVERLOAD_BROKEN typedCall=true objectCall=false" "$BUILD_DIR/overload.err"

cat "$BUILD_DIR/solution.out"
echo "EXPECTED_COMPILE_FAILURE InvalidOverrideFailure status=$override_status evidence=wrong-equals-signature"
echo "EXPECTED_FAILURE HashFieldMismatchFailure status=$hash_status evidence=field-set-mismatch"
echo "EXPECTED_FAILURE ToStringLeakFailure status=$leak_status evidence=canary-detected"
echo "EXPECTED_FAILURE EqualsOverloadFailure status=$overload_status evidence=overload-not-override"
echo "SOLUTION PASS assertions=16 expected_failures=4 java=$JAVA_VERSION"
