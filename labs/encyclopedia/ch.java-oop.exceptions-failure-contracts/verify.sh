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
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/ExceptionContractsLab.java"
java -cp "$CLASSES_DIR" ExceptionContractsLab > "$BUILD_DIR/lab.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
report.success=Outcome[code=CREATED, detail=WO-2001, causeName=none]
report.invalid=Outcome[code=INVALID_INPUT, detail=title must have text, causeName=none]
report.conflict=Outcome[code=CONFLICT, detail=REQ-7, causeName=none]
report.system=Outcome[code=SYSTEM_ERROR, detail=create unavailable, causeName=GatewayException]
resource.order=open:A,open:B,use,close:B,close:A
suppressed.primary=operation failed
suppressed.count=1
assertions=20 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"

cp "$ROOT_DIR/failures/UnhandledCheckedFailure.java.txt" "$BUILD_DIR/failure-src/UnhandledCheckedFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/UnhandledCheckedFailure.java" > "$BUILD_DIR/checked.out" 2> "$BUILD_DIR/checked.err"; checked_status=$?
javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR/failures/SwallowedFailure.java" "$ROOT_DIR/failures/LostCauseFailure.java" "$ROOT_DIR/failures/MisclassifiedInputFailure.java" "$ROOT_DIR/failures/OverBroadCatchFailure.java" "$ROOT_DIR/failures/SuppressedLossFailure.java" > "$BUILD_DIR/failures-compile.out" 2> "$BUILD_DIR/failures-compile.err"; runtime_compile_status=$?
java -cp "$FAILURE_CLASSES" SwallowedFailure > "$BUILD_DIR/swallow.out" 2> "$BUILD_DIR/swallow.err"; swallow_status=$?
java -cp "$FAILURE_CLASSES" LostCauseFailure > "$BUILD_DIR/cause.out" 2> "$BUILD_DIR/cause.err"; cause_status=$?
java -cp "$FAILURE_CLASSES" MisclassifiedInputFailure > "$BUILD_DIR/input.out" 2> "$BUILD_DIR/input.err"; input_status=$?
java -cp "$FAILURE_CLASSES" OverBroadCatchFailure > "$BUILD_DIR/broad.out" 2> "$BUILD_DIR/broad.err"; broad_status=$?
java -cp "$FAILURE_CLASSES" SuppressedLossFailure > "$BUILD_DIR/suppressed.out" 2> "$BUILD_DIR/suppressed.err"; suppressed_status=$?
set -e
[[ $checked_status -ne 0 && $runtime_compile_status -eq 0 ]]
[[ $swallow_status -eq 4 && $cause_status -eq 5 && $input_status -eq 6 && $broad_status -eq 7 && $suppressed_status -eq 8 ]]
grep -Fq "compiler.err.unreported.exception.need.to.catch.or.throw" "$BUILD_DIR/checked.err"
grep -Fqx "SWALLOWED_FAILURE result=null causeLost=true" "$BUILD_DIR/swallow.err"
grep -Fqx "CAUSE_LOST outer=CreationException cause=null" "$BUILD_DIR/cause.err"
grep -Fqx "INPUT_MISCLASSIFIED expected=INVALID_INPUT actual=SYSTEM_ERROR" "$BUILD_DIR/input.err"
grep -Fqx "BUG_MISCLASSIFIED exception=NullPointerException actual=INVALID_INPUT" "$BUILD_DIR/broad.err"
grep -Fqx "SUPPRESSED_LOST primary=operation-failed suppressed=0" "$BUILD_DIR/suppressed.err"

cat "$BUILD_DIR/lab.out"
echo "EXPECTED_COMPILE_FAILURE UnhandledCheckedFailure status=$checked_status evidence=catch-or-declare"
echo "EXPECTED_FAILURE SwallowedFailure status=$swallow_status evidence=empty-catch-null"
echo "EXPECTED_FAILURE LostCauseFailure status=$cause_status evidence=cause-null"
echo "EXPECTED_FAILURE MisclassifiedInputFailure status=$input_status evidence=wrong-boundary-result"
echo "EXPECTED_FAILURE OverBroadCatchFailure status=$broad_status evidence=program-bug-hidden"
echo "EXPECTED_FAILURE SuppressedLossFailure status=$suppressed_status evidence=close-failure-lost"
echo "LAB PASS assertions=20 expected_failures=6 java=$JAVA_VERSION"
