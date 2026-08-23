#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"

JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in
  "javac 25"|"javac 25."*) ;;
  *)
    echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2
    exit 2
    ;;
esac
case "$JAVA_VERSION" in
  *'version "25.'*|*'version "25"'*) ;;
  *)
    echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2
    exit 2
    ;;
esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"

javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java
java -cp "$CLASSES_DIR" ExpressionsDemo > "$BUILD_DIR/demo.out"

expected_lines=(
  "precedence=14"
  "parenthesized=20"
  "shortCircuited=false"
  "comparison=true"
  "promotedByteSum=42"
  "integerDivision=2"
  "widenedAfterDivision=2.0"
  "floatingDivision=2.5"
  "negativeDivision=-2"
  "negativeRemainder=-1"
  "narrowed=-1294967296"
  "rawOverflow=-2147483648"
  "widenedBeforeMultiply=2147483648"
  "splitEach=333"
  "splitRemainder=1"
  "stringTrap=12"
  "stringGrouped=3"
)

for line in "${expected_lines[@]}"; do
  grep -Fqx "$line" "$BUILD_DIR/demo.out"
done
actual_line_count="$(wc -l < "$BUILD_DIR/demo.out" | tr -d '[:space:]')"
if [[ "$actual_line_count" != "${#expected_lines[@]}" ]]; then
  echo "UNEXPECTED OUTPUT: expected ${#expected_lines[@]} lines, got $actual_line_count" >&2
  cat "$BUILD_DIR/demo.out" >&2
  exit 1
fi

expect_runtime_failure() {
  local class_name="$1"
  local expected_message="$2"
  local log="$BUILD_DIR/${class_name}.err"
  set +e
  java -cp "$CLASSES_DIR" "$class_name" > "$log" 2>&1
  local status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    echo "EXPECTED FAILURE: $class_name exited 0" >&2
    exit 1
  fi
  grep -Fq "$expected_message" "$log"
  grep -Fq "at ${class_name}.main" "$log"
}

expect_runtime_failure DivisionByZeroFailure "java.lang.ArithmeticException: / by zero"
expect_runtime_failure EagerBooleanFailure "java.lang.ArithmeticException: / by zero"
expect_runtime_failure CheckedOverflowFailure "java.lang.ArithmeticException: integer overflow"

cp "$ROOT_DIR/failures/NarrowingCompileError.java.txt" "$BUILD_DIR/NarrowingCompileError.java"
set +e
javac -J-Duser.language=en -J-Duser.country=US --release 25 \
  -d "$CLASSES_DIR" "$BUILD_DIR/NarrowingCompileError.java" \
  > "$BUILD_DIR/NarrowingCompileError.out" 2> "$BUILD_DIR/NarrowingCompileError.err"
narrowing_status=$?
set -e
if [[ $narrowing_status -eq 0 ]]; then
  echo "EXPECTED FAILURE: narrowing source compiled successfully" >&2
  exit 1
fi
grep -Fq "possible lossy conversion from long to int" "$BUILD_DIR/NarrowingCompileError.err"
grep -Fq "NarrowingCompileError.java:" "$BUILD_DIR/NarrowingCompileError.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_FAILURE DivisionByZeroFailure status=nonzero evidence=ArithmeticException"
echo "EXPECTED_FAILURE EagerBooleanFailure status=nonzero evidence=ArithmeticException"
echo "EXPECTED_FAILURE CheckedOverflowFailure status=nonzero evidence=ArithmeticException"
echo "EXPECTED_FAILURE NarrowingCompileError status=nonzero evidence=possible-lossy-conversion"
echo "EXAMPLES PASS javac=$JAVAC_VERSION java=$JAVA_VERSION"
