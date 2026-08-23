#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java
java -cp "$CLASSES_DIR" ConstructorInvariantDemo > "$BUILD_DIR/demo.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
trace=field:status
trace=constructor:body
created=PUMP-01|北区循环泵|REGISTERED
trace=field:status
trace=constructor:body
trace=constructor:overload
explicit=VALVE-02|供水阀|IDLE
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

set +e
java -cp "$CLASSES_DIR" InvalidConstructionFailure > "$BUILD_DIR/invalid.out" 2> "$BUILD_DIR/invalid.err"
invalid_status=$?
set -e
[[ $invalid_status -ne 0 ]]
grep -Fq "java.lang.IllegalArgumentException: code must not be blank" "$BUILD_DIR/invalid.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_FAILURE InvalidConstructionFailure status=$invalid_status evidence=blank-code-rejected"
echo "EXAMPLE PASS lines=7 javac=$JAVAC_VERSION java=$JAVA_VERSION"
