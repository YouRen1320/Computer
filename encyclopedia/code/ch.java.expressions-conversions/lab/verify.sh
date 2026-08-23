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

java -cp "$CLASSES_DIR" MoneyLab > "$BUILD_DIR/lab.out"
java -ea -cp "$CLASSES_DIR" MoneyLabTest > "$BUILD_DIR/test.out"

grep -Fqx "totalCents=5997" "$BUILD_DIR/lab.out"
grep -Fqx "unitPriceCents=1999" "$BUILD_DIR/lab.out"
grep -Fqx "quantity=3" "$BUILD_DIR/lab.out"
grep -Fqx "allocationEachCents=1499" "$BUILD_DIR/lab.out"
grep -Fqx "allocationRemainderCents=1" "$BUILD_DIR/lab.out"
grep -Fqx "assertions=8 passed" "$BUILD_DIR/test.out"
lab_line_count="$(wc -l < "$BUILD_DIR/lab.out" | tr -d '[:space:]')"
test_line_count="$(wc -l < "$BUILD_DIR/test.out" | tr -d '[:space:]')"
if [[ "$lab_line_count" != "5" || "$test_line_count" != "1" ]]; then
  echo "UNEXPECTED OUTPUT: lab=$lab_line_count lines test=$test_line_count lines" >&2
  exit 1
fi

set +e
java -cp "$CLASSES_DIR" MoneyOverflowProbe > "$BUILD_DIR/overflow.out" 2> "$BUILD_DIR/overflow.err"
overflow_status=$?
set -e
if [[ $overflow_status -eq 0 ]]; then
  echo "EXPECTED FAILURE: MoneyOverflowProbe exited 0" >&2
  exit 1
fi
grep -Fq "java.lang.ArithmeticException: integer overflow" "$BUILD_DIR/overflow.err"
grep -Fq "at MoneyOverflowProbe.main" "$BUILD_DIR/overflow.err"

cat "$BUILD_DIR/lab.out"
cat "$BUILD_DIR/test.out"
echo "EXPECTED_FAILURE MoneyOverflowProbe status=$overflow_status evidence=ArithmeticException"
echo "LAB PASS normal=5997 zero=0 boundary=2147483646 widened=2147483648 java=$JAVA_VERSION"
