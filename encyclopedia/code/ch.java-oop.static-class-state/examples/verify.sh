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
mkdir -p "$CLASSES_DIR" "$BUILD_DIR/failure-src" "$BUILD_DIR/failure-classes"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/ClassStateDemo.java"
java -cp "$CLASSES_DIR" ClassStateDemo > "$BUILD_DIR/demo.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
first=FC-1:PUMP
second=FC-2:VALVE
created=2
init=1B3|10|20|30
assertions=8 passed
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

cp "$ROOT_DIR/failures/StaticReadsInstanceFailure.java.txt" "$BUILD_DIR/failure-src/StaticReadsInstanceFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$BUILD_DIR/failure-classes" "$BUILD_DIR/failure-src/StaticReadsInstanceFailure.java" > "$BUILD_DIR/static.out" 2> "$BUILD_DIR/static.err"
static_status=$?
javac --release 25 -d "$BUILD_DIR/failure-classes" "$ROOT_DIR/failures/GlobalCounterOrderFailure.java" > "$BUILD_DIR/order-compile.out" 2> "$BUILD_DIR/order-compile.err"
order_compile_status=$?
java -cp "$BUILD_DIR/failure-classes" GlobalCounterOrderFailure > "$BUILD_DIR/order.out" 2> "$BUILD_DIR/order.err"
order_status=$?
set -e
[[ $static_status -ne 0 ]]
[[ $order_compile_status -eq 0 ]]
[[ $order_status -ne 0 ]]
grep -Fq "compiler.err.non-static.cant.be.ref" "$BUILD_DIR/static.err"
grep -Fqx "ORDER_DEPENDENCY expected=WO-0001 actual=WO-0002" "$BUILD_DIR/order.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_COMPILE_FAILURE StaticReadsInstanceFailure status=$static_status evidence=static-context"
echo "EXPECTED_FAILURE GlobalCounterOrderFailure status=$order_status evidence=order-dependency"
echo "EXAMPLE PASS assertions=8 expected_failures=2 java=$JAVA_VERSION"
