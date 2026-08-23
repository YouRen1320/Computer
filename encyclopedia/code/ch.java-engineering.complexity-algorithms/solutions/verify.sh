#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR/src/ComplexityAlgorithmsChallenge.java" "$ROOT_DIR/failures/UnsortedBinarySearchContractFailure.java"
java -cp "$CLASSES_DIR" ComplexityAlgorithmsChallenge > "$BUILD_DIR/solution.out"
grep -Fqx 'exercise.assertions=15 passed' "$BUILD_DIR/solution.out"
set +e
java -cp "$CLASSES_DIR" UnsortedBinarySearchContractFailure > "$BUILD_DIR/failure.out" 2> "$BUILD_DIR/failure.err"
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
grep -Fq 'UNSORTED_PRECONDITION' "$BUILD_DIR/failure.err"
printf 'PRIVATE SOLUTION PASS assertions=15 runtime_failures=1 warnings=0 jdk=25\n'
