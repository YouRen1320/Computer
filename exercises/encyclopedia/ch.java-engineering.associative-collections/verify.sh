#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR/src/AssociativeCollectionsChallenge.java"
set +e
java -cp "$CLASSES_DIR" AssociativeCollectionsChallenge > "$BUILD_DIR/challenge.out" 2> "$BUILD_DIR/challenge.err"
challenge_status=$?
set -e
if [[ $challenge_status -ne 0 ]]; then
    grep -Fq 'AssertionError' "$BUILD_DIR/challenge.err"
    printf 'STARTER EXPECTED FAILURE status=%s reason=key-or-map-contract; complete TODO 1..4\n' "$challenge_status"
    exit 41
fi

grep -Fqx 'exercise.assertions=14 passed' "$BUILD_DIR/challenge.out"
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR/failures/MutableKeyContractFailure.java"
set +e
java -cp "$CLASSES_DIR" MutableKeyContractFailure > "$BUILD_DIR/failure.out" 2> "$BUILD_DIR/failure.err"
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
grep -Fq 'LOST_HASH_KEY' "$BUILD_DIR/failure.err"
printf 'EXERCISE PASS assertions=14 runtime_failures=1 warnings=0 jdk=25\n'
