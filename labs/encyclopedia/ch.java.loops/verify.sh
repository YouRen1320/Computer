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
java -cp "$CLASSES_DIR" LoopBoundaryLab > "$BUILD_DIR/lab.out"
java -ea -cp "$CLASSES_DIR" LoopBoundaryOracle > "$BUILD_DIR/oracle.out"

expected_lines=(
  "n0.count=0 sum=0"
  "n1.count=1 sum=1"
  "n4.count=4 sum=10"
  "while.steps=3 remaining=0"
  "doWhile.attempts=1"
  "sentinel.handled=3 value=0"
  "control.processed=3 skipped=1 stoppedAt=5 sum=8"
)
for line in "${expected_lines[@]}"; do grep -Fqx "$line" "$BUILD_DIR/lab.out"; done
grep -Fqx "assertions=10 passed" "$BUILD_DIR/oracle.out"
[[ "$(wc -l < "$BUILD_DIR/lab.out" | tr -d '[:space:]')" == "${#expected_lines[@]}" ]]
[[ "$(wc -l < "$BUILD_DIR/oracle.out" | tr -d '[:space:]')" == "1" ]]

set +e
java -cp "$CLASSES_DIR" MissingUpdateProbe > "$BUILD_DIR/missing-update.out" 2> "$BUILD_DIR/missing-update.err"
failure_status=$?
set -e
if [[ $failure_status -eq 0 ]]; then echo "EXPECTED FAILURE: missing-update probe exited 0" >&2; exit 1; fi
grep -Fqx "LOOP_BUDGET_EXCEEDED sentinel=2 safetySteps=5" "$BUILD_DIR/missing-update.err"

cat "$BUILD_DIR/lab.out"
cat "$BUILD_DIR/oracle.out"
echo "EXPECTED_FAILURE MissingUpdateProbe status=$failure_status evidence=LOOP_BUDGET_EXCEEDED"
echo "LAB PASS n0=0 n1=1 n4=10 termination=guarded assertions=10 java=$JAVA_VERSION"
