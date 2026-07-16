#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C LANG=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED JDK 25, got: $JAVAC_VERSION" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/WorkOrderAmountCli.java"

run_case() {
  local name="$1" expected_status="$2" expected_stdout="$3" expected_stderr="$4" input="$5"
  shift 5
  set +e
  printf '%s' "$input" | java -cp "$CLASSES_DIR" WorkOrderAmountCli "$@" > "$BUILD_DIR/$name.out" 2> "$BUILD_DIR/$name.err"
  local status=$?
  set -e
  [[ $status -eq $expected_status ]]
  [[ "$(cat "$BUILD_DIR/$name.out")" == "$expected_stdout" ]]
  [[ "$(cat "$BUILD_DIR/$name.err")" == "$expected_stderr" ]]
  echo "CASE $name status=$status stdout=$(wc -l < "$BUILD_DIR/$name.out" | tr -d ' ') stderr=$(wc -l < "$BUILD_DIR/$name.err" | tr -d ' ')"
}

run_case args-success 0 "totalCents=5997" "" "" 1999 3
run_case stdin-success 0 "totalCents=2500" "" $'1250 2\n'
run_case zero-quantity 0 "totalCents=0" "" "" 1999 0
run_case missing-argument 64 "" "ERROR USAGE: expected exactly 2 arguments" "" 1999
run_case invalid-number 65 "" "ERROR DATA: both values must be integers" "" abc 3
run_case invalid-range 65 "" "ERROR DATA: price must be positive and quantity non-negative" "" 1999 -1
run_case eof 66 "" "ERROR EOF: expected unitPriceCents quantity" ""

echo "EXAMPLES PASS console-input cases=7 java=$JAVA_VERSION"
