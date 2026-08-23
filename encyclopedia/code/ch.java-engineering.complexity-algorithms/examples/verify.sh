#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java
java -cp "$CLASSES_DIR" ComplexitySearchDemo > "$BUILD_DIR/demo.out"
printf '%s\n' \
  'linear.missing.comparisons=128' \
  'binary.missing.comparisons=8' \
  'linear.found.index=73,comparisons=74' \
  'binary.found.index=73,comparisons=6' \
  'model.n=100,linear=100,binaryCeiling=7' \
  'model.n=10000,linear=10000,binaryCeiling=14' \
  'model.n=1000000,linear=1000000,binaryCeiling=20' \
  'nested.unique.n=16,pairs=120' \
  'map.index.size=128' \
  'map.lookup=WO-073' > "$BUILD_DIR/expected.out"
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

set +e
java -cp "$CLASSES_DIR" UnsortedBinarySearchFailure > "$BUILD_DIR/failure.out" 2> "$BUILD_DIR/failure.err"
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
grep -Fq 'UNSORTED_PRECONDITION' "$BUILD_DIR/failure.err"

cat "$BUILD_DIR/demo.out"
printf 'EXPECTED_RUNTIME_FAILURE UnsortedBinarySearchFailure status=%s evidence=UNSORTED_PRECONDITION\n' "$failure_status"
printf 'EXAMPLE PASS lines=10 runtime_failures=1 warnings=0 jdk=25\n'
