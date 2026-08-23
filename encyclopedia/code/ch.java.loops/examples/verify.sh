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
java -cp "$CLASSES_DIR" LoopsDemo > "$BUILD_DIR/demo.out"

expected_lines=(
  "for.tick=1"
  "for.tick=2"
  "for.tick=3"
  "for.sum=6"
  "while.steps=3 remaining=0"
  "doWhile.attempts=1"
  "sentinel.processed=3 value=0"
  "control.accepted=3 stoppedAt=5"
)
for line in "${expected_lines[@]}"; do grep -Fqx "$line" "$BUILD_DIR/demo.out"; done
[[ "$(wc -l < "$BUILD_DIR/demo.out" | tr -d '[:space:]')" == "${#expected_lines[@]}" ]]

set +e
java -cp "$CLASSES_DIR" NonTerminatingProbe > "$BUILD_DIR/non-terminating.out" 2> "$BUILD_DIR/non-terminating.err"
failure_status=$?
set -e
if [[ $failure_status -eq 0 ]]; then echo "EXPECTED FAILURE: missing-update probe exited 0" >&2; exit 1; fi
grep -Fqx "NON_TERMINATING_GUARD remaining=3 safetySteps=4" "$BUILD_DIR/non-terminating.err"

cat "$BUILD_DIR/demo.out"
echo "EXPECTED_FAILURE NonTerminatingProbe status=$failure_status evidence=NON_TERMINATING_GUARD"
echo "EXAMPLES PASS javac=$JAVAC_VERSION java=$JAVA_VERSION"
