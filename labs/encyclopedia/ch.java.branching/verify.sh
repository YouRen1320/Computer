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
java -cp "$CLASSES_DIR" PriorityRoutingLab > "$BUILD_DIR/lab.out"
java -ea -cp "$CLASSES_DIR" PriorityRoutingOracle > "$BUILD_DIR/oracle.out"

expected_lines=("min=ROUTINE" "middle=HIGH" "max=CRITICAL" "invalidLow=REJECTED" "invalidHigh=REJECTED" "status=WORK")
for line in "${expected_lines[@]}"; do grep -Fqx "$line" "$BUILD_DIR/lab.out"; done
grep -Fqx "assertions=9 passed" "$BUILD_DIR/oracle.out"
[[ "$(wc -l < "$BUILD_DIR/lab.out" | tr -d '[:space:]')" == "6" ]]
[[ "$(wc -l < "$BUILD_DIR/oracle.out" | tr -d '[:space:]')" == "1" ]]

set +e
java -cp "$CLASSES_DIR" FallthroughFailure > "$BUILD_DIR/fallthrough.out" 2> "$BUILD_DIR/fallthrough.err"
failure_status=$?
set -e
if [[ $failure_status -eq 0 ]]; then echo "EXPECTED FAILURE: fallthrough probe exited 0" >&2; exit 1; fi
grep -Fqx "FALLTHROUGH_DETECTED expected=1 actual=2" "$BUILD_DIR/fallthrough.err"

cat "$BUILD_DIR/lab.out"
cat "$BUILD_DIR/oracle.out"
echo "EXPECTED_FAILURE FallthroughFailure status=$failure_status evidence=FALLTHROUGH_DETECTED"
echo "LAB PASS boundaries=5 switch=WORK assertions=9 java=$JAVA_VERSION"
