#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR/src/ComplexityAlgorithmsChallenge.java"
set +e
java -cp "$CLASSES_DIR" ComplexityAlgorithmsChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"
challenge_status=$?
set -e
if [[ $challenge_status -ne 0 ]]; then
    grep -Eq 'AssertionError|NullPointerException' "$BUILD_DIR/challenge.err"
    printf 'STARTER EXPECTED FAILURE status=%s reason=complexity-or-index-contract; complete TODO 1..3\n' "$challenge_status"
    printf '%s\n' 'EXPECTED_RED chapter=ch.java-engineering.complexity-algorithms oracle=verified-starter-failure'
    exit 41
fi

grep -Fqx 'exercise.assertions=15 passed' "$BUILD_DIR/challenge.out"
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR/failures/UnsortedBinarySearchContractFailure.java"
set +e
java -cp "$CLASSES_DIR" UnsortedBinarySearchContractFailure > "$BUILD_DIR/failure.out" 2> "$BUILD_DIR/failure.err"
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
grep -Fq 'UNSORTED_PRECONDITION' "$BUILD_DIR/failure.err"
printf 'EXERCISE PASS assertions=15 runtime_failures=1 warnings=0 jdk=25\n'
