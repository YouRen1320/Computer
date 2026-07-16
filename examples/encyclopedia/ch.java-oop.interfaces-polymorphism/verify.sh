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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/InterfacesPolymorphismDemo.java"
java -cp "$CLASSES_DIR" InterfacesPolymorphismDemo > "$BUILD_DIR/demo.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
sms=SMS|AUDIT|WO-1001|inspect
mail=MAIL|AUDIT|WO-1002|lubricate
recorded=RECORDED|WO-1003
contract=notification-v1
runtime.mail=EmailSender
recording.observed=WO-1003|calibrate
assertions=17 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

cp "$ROOT_DIR/failures/MissingImplementationFailure.java.txt" "$BUILD_DIR/failure-src/MissingImplementationFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/MissingImplementationFailure.java" > "$BUILD_DIR/missing.out" 2> "$BUILD_DIR/missing.err"
missing_status=$?
javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR/failures/WrongCastFailure.java" "$ROOT_DIR/failures/TypeBranchFailure.java" > "$BUILD_DIR/failures-compile.out" 2> "$BUILD_DIR/failures-compile.err"
failure_compile_status=$?
java -cp "$FAILURE_CLASSES" WrongCastFailure > "$BUILD_DIR/cast.out" 2> "$BUILD_DIR/cast.err"
cast_status=$?
java -cp "$FAILURE_CLASSES" TypeBranchFailure > "$BUILD_DIR/branch.out" 2> "$BUILD_DIR/branch.err"
branch_status=$?
set -e
[[ $missing_status -ne 0 ]]
[[ $failure_compile_status -eq 0 ]]
[[ $cast_status -eq 4 ]]
[[ $branch_status -eq 5 ]]
grep -Fq "compiler.err.does.not.override.abstract" "$BUILD_DIR/missing.err"
grep -Fqx "WRONG_CAST actual=EmailSender target=SmsSender exception=ClassCastException" "$BUILD_DIR/cast.err"
grep -Fqx "TYPE_BRANCH_BROKEN implementation=RecordingSender reason=unsupported" "$BUILD_DIR/branch.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_COMPILE_FAILURE MissingImplementationFailure status=$missing_status evidence=interface-contract"
echo "EXPECTED_FAILURE WrongCastFailure status=$cast_status evidence=ClassCastException"
echo "EXPECTED_FAILURE TypeBranchFailure status=$branch_status evidence=third-implementation"
echo "EXAMPLE PASS assertions=17 expected_failures=3 java=$JAVA_VERSION"
