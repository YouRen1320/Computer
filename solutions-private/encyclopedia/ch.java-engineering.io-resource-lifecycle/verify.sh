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
mkdir -p "$CLASSES_DIR" "$FAILURE_CLASSES"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/IoLifecycleSolution.java"
java -cp "$CLASSES_DIR" IoLifecycleSolution > "$BUILD_DIR/solution.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
solution.text.roundTrip=true
solution.closed=input:true,output:true
solution.empty=0
solution.borrowed.closed=reader:false,writer:false
solution.suppressed=2
solution.assertions=16 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/solution.out"

javac --release 25 -d "$FAILURE_CLASSES" "$ROOT_DIR"/failures/*.java
set +e
java -cp "$FAILURE_CLASSES" SwallowedIoFailure > "$BUILD_DIR/swallow.out" 2> "$BUILD_DIR/swallow.err"; swallow_status=$?
java -cp "$FAILURE_CLASSES" LostCauseFailure > "$BUILD_DIR/cause.out" 2> "$BUILD_DIR/cause.err"; cause_status=$?
java -cp "$FAILURE_CLASSES" UnclosedStreamFailure > "$BUILD_DIR/leak.out" 2> "$BUILD_DIR/leak.err"; leak_status=$?
java -cp "$FAILURE_CLASSES" CloseOverridesReadFailure > "$BUILD_DIR/override.out" 2> "$BUILD_DIR/override.err"; override_status=$?
java -cp "$FAILURE_CLASSES" BufferCountFailure > "$BUILD_DIR/buffer.out" 2> "$BUILD_DIR/buffer.err"; buffer_status=$?
set -e
[[ $swallow_status -eq 4 && $cause_status -eq 5 && $leak_status -eq 6 && $override_status -eq 7 && $buffer_status -eq 8 ]]
grep -Fqx "SWALLOWED_IO expected=failure actual=empty-text" "$BUILD_DIR/swallow.err"
grep -Fqx "IO_CAUSE_LOST outer=CopyException cause=null" "$BUILD_DIR/cause.err"
grep -Fqx "STREAM_LEAK owner=missing closed=false" "$BUILD_DIR/leak.err"
grep -Fqx "PRIMARY_OVERRIDDEN actual=close-failed original=read-failed suppressed=0" "$BUILD_DIR/override.err"
grep -Fqx "BUFFER_COUNT_IGNORED expectedLength=5 actualLength=8" "$BUILD_DIR/buffer.err"

cat "$BUILD_DIR/solution.out"
echo "EXPECTED_FAILURE SwallowedIoFailure status=$swallow_status evidence=empty-text"
echo "EXPECTED_FAILURE LostCauseFailure status=$cause_status evidence=cause-null"
echo "EXPECTED_FAILURE UnclosedStreamFailure status=$leak_status evidence=closed-false"
echo "EXPECTED_FAILURE CloseOverridesReadFailure status=$override_status evidence=primary-lost"
echo "EXPECTED_FAILURE BufferCountFailure status=$buffer_status evidence=read-count-ignored"
echo "SOLUTION PASS assertions=16 expected_failures=5 java=$JAVA_VERSION"
