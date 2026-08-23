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
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java "$ROOT_DIR"/failures/*.java
java -cp "$CLASSES_DIR" SequentialCollectionsOracle > "$BUILD_DIR/lab.out"
grep -Fqx 'report.input=WO-201,WO-202,WO-201' "$BUILD_DIR/lab.out"
grep -Fqx 'report.fifo=WO-201,WO-202,WO-203' "$BUILD_DIR/lab.out"
grep -Fqx 'report.lifo=assign:WO-203,assign:WO-202,assign:WO-201' "$BUILD_DIR/lab.out"
grep -Fqx 'report.snapshot=RECEIVED,VALIDATED;view=RECEIVED,VALIDATED,ASSIGNED' "$BUILD_DIR/lab.out"
grep -Fqx 'assertions=18 passed' "$BUILD_DIR/lab.out"

failure_count=0
for name in ConcurrentModificationFailure EmptyQueueRemoveFailure UnmodifiableMutationFailure IndexBoundaryFailure; do
    case "$name" in
        ConcurrentModificationFailure) expected='ConcurrentModificationException' ;;
        EmptyQueueRemoveFailure) expected='NoSuchElementException' ;;
        UnmodifiableMutationFailure) expected='UnsupportedOperationException' ;;
        IndexBoundaryFailure) expected='IndexOutOfBoundsException' ;;
    esac
    set +e
    java -cp "$CLASSES_DIR" "$name" > "$BUILD_DIR/$name.out" 2> "$BUILD_DIR/$name.err"
    status=$?
    set -e
    [[ $status -ne 0 ]]
    grep -Fq "$expected" "$BUILD_DIR/$name.err"
    failure_count=$((failure_count + 1))
    printf 'EXPECTED_RUNTIME_FAILURE %s status=%s evidence=%s\n' "$name" "$status" "$expected"
done
[[ $failure_count -eq 4 ]]

cat "$BUILD_DIR/lab.out"
printf 'LAB PASS assertions=18 runtime_failures=4 warnings=0 jdk=25\n'
