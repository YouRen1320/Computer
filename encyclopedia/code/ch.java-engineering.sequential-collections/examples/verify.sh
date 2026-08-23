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
java -cp "$CLASSES_DIR" SequentialCollectionsDemo > "$BUILD_DIR/demo.out"
printf '%s\n' \
  'list.order=WO-101,WO-102,WO-101' \
  'list.size=3' \
  'list.afterIteratorRemove=WO-101,WO-101' \
  'queue.fifo=WO-101,WO-102,WO-103' \
  'queue.empty.poll=null' \
  'queue.empty.peek=null' \
  'deque.lifo=assign:WO-103,assign:WO-102,assign:WO-101' \
  'view.size.afterSourceMutation=3' \
  'snapshot.size.afterSourceMutation=2' \
  'snapshot.first=RECEIVED' > "$BUILD_DIR/expected.out"
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

set +e
java -cp "$CLASSES_DIR" ConcurrentModificationFailure > "$BUILD_DIR/failure.out" 2> "$BUILD_DIR/failure.err"
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
grep -Fq 'ConcurrentModificationException' "$BUILD_DIR/failure.err"

cat "$BUILD_DIR/demo.out"
printf 'EXPECTED_RUNTIME_FAILURE ConcurrentModificationFailure status=%s evidence=ConcurrentModificationException\n' "$failure_status"
printf 'EXAMPLE PASS lines=10 runtime_failures=1 warnings=0 jdk=25\n'
