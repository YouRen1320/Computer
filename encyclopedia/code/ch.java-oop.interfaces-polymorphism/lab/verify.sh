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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/InterfacesPolymorphismLab.java"
java -cp "$CLASSES_DIR" InterfacesPolymorphismLab > "$BUILD_DIR/lab.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
sms=SMS|AUDIT|WO-1001|inspect
mail=MAIL|AUDIT|WO-1001|inspect
recorded=RECORDED|WO-1001
runtime=SmsSender,EmailSender,RecordingSender
service.calls=3
assertions=15 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"

cp "$ROOT_DIR/failures/MissingMethodFailure.java.txt" "$BUILD_DIR/failure-src/MissingMethodFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/MissingMethodFailure.java" > "$BUILD_DIR/missing.out" 2> "$BUILD_DIR/missing.err"
missing_status=$?
javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR/failures/WrongCastFailure.java" "$ROOT_DIR/failures/ThirdImplementationBranchFailure.java" "$ROOT_DIR/failures/ContractViolationFailure.java" > "$BUILD_DIR/failures-compile.out" 2> "$BUILD_DIR/failures-compile.err"
failure_compile_status=$?
java -cp "$FAILURE_CLASSES" WrongCastFailure > "$BUILD_DIR/cast.out" 2> "$BUILD_DIR/cast.err"
cast_status=$?
java -cp "$FAILURE_CLASSES" ThirdImplementationBranchFailure > "$BUILD_DIR/branch.out" 2> "$BUILD_DIR/branch.err"
branch_status=$?
java -cp "$FAILURE_CLASSES" ContractViolationFailure > "$BUILD_DIR/contract.out" 2> "$BUILD_DIR/contract.err"
contract_status=$?
set -e
[[ $missing_status -ne 0 ]]
[[ $failure_compile_status -eq 0 ]]
[[ $cast_status -eq 6 ]]
[[ $branch_status -eq 7 ]]
[[ $contract_status -eq 8 ]]
grep -Fq "compiler.err.does.not.override.abstract" "$BUILD_DIR/missing.err"
grep -Fqx "LAB_WRONG_CAST actual=EmailSender target=SmsSender exception=ClassCastException" "$BUILD_DIR/cast.err"
grep -Fqx "LAB_TYPE_BRANCH_BROKEN implementation=RecordingSender" "$BUILD_DIR/branch.err"
grep -Fqx "LAB_CONTRACT_BROKEN input=blank expected=IllegalArgumentException actual=success" "$BUILD_DIR/contract.err"

cat "$BUILD_DIR/lab.out"
echo "EXPECTED_COMPILE_FAILURE MissingMethodFailure status=$missing_status evidence=interface-method"
echo "EXPECTED_FAILURE WrongCastFailure status=$cast_status evidence=ClassCastException"
echo "EXPECTED_FAILURE ThirdImplementationBranchFailure status=$branch_status evidence=third-implementation"
echo "EXPECTED_FAILURE ContractViolationFailure status=$contract_status evidence=substitution"
echo "LAB PASS assertions=15 expected_failures=4 java=$JAVA_VERSION"
