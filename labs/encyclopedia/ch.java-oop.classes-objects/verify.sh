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
java -cp "$CLASSES_DIR" DeviceObjectsLab > "$BUILD_DIR/lab.out"
java -ea -cp "$CLASSES_DIR" DeviceObjectsOracle > "$BUILD_DIR/oracle.out"
cat > "$BUILD_DIR/expected.out" <<'EXPECTED'
pump=PUMP-01:ACTIVE
sensor=TEMP-08:OFFLINE
sameInstance=false
EXPECTED
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/lab.out"
grep -Fqx "assertions=10 passed" "$BUILD_DIR/oracle.out"

set +e
java -cp "$CLASSES_DIR" LocalShadowingFailure > "$BUILD_DIR/shadow.out" 2> "$BUILD_DIR/shadow.err"
shadow_status=$?
set -e
[[ $shadow_status -ne 0 ]]
grep -Fqx "LOCAL_SHADOWING expected=TEMP-08 actual=SENSOR-07" "$BUILD_DIR/shadow.err"

cat "$BUILD_DIR/lab.out"
cat "$BUILD_DIR/oracle.out"
echo "EXPECTED_FAILURE LocalShadowingFailure status=$shadow_status evidence=LOCAL_SHADOWING"
echo "LAB PASS assertions=10 instances=2 java=$JAVA_VERSION"
