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
java -cp "$CLASSES_DIR" DeviceObjectsDemo > "$BUILD_DIR/demo.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
sameInstance=false
pump=PUMP-01:ACTIVE
sensor=SENSOR-07:IDLE
sensor.renamed=TEMP-08:IDLE
parsed=VALVE-09:RUNNING
pump.still=PUMP-01:ACTIVE
sensor.still=TEMP-08:IDLE
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

set +e
java -cp "$CLASSES_DIR" ShadowingFailure > "$BUILD_DIR/shadow.out" 2> "$BUILD_DIR/shadow.err"
shadow_status=$?
set -e
[[ $shadow_status -ne 0 ]]
grep -Fqx "SHADOWING_FAILURE expected=PUMP-02 actual=PUMP-01" "$BUILD_DIR/shadow.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_FAILURE ShadowingFailure status=$shadow_status evidence=field-unchanged"
echo "EXAMPLE PASS lines=7 java=$JAVA_VERSION"
