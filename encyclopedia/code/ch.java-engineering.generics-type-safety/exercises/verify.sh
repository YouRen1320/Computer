#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
set +e
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR/src/GenericBoundaryChallenge.java" > "$BUILD_DIR/compile.out" 2> "$BUILD_DIR/compile.err"
compile_status=$?
set -e
if [[ $compile_status -ne 0 ]]; then
    grep -Eqi 'warning|rawtypes|unchecked' "$BUILD_DIR/compile.err"
    printf 'STARTER EXPECTED FAILURE status=%s reason=raw-or-unchecked; complete TODO 1..2\n' "$compile_status"
    printf '%s\n' 'EXPECTED_RED chapter=ch.java-engineering.generics-type-safety oracle=verified-starter-failure'
    exit 41
fi

java -cp "$CLASSES_DIR" GenericBoundaryChallenge > "$BUILD_DIR/challenge.out"
grep -Fqx 'exercise.assertions=10 passed' "$BUILD_DIR/challenge.out"

set +e
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR/failures/WrongTargetFailure.java" > "$BUILD_DIR/failure.out" 2> "$BUILD_DIR/failure.err"
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
grep -Fq 'WrongTargetFailure.java' "$BUILD_DIR/failure.err"
printf 'EXERCISE PASS assertions=10 compile_failures=1 warnings=0 jdk=25\n'
