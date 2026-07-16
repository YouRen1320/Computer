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
java -cp "$CLASSES_DIR" SortingComparatorsDemo > "$BUILD_DIR/demo.out"
printf '%s\n' \
  'natural.deviceIds=FAN-02,PUMP-01' \
  'dispatch.order=WO-101,WO-102,WO-103,WO-104' \
  'dispatch.first.priority=3' \
  'dispatch.first.createdAt=2026-07-16T09:00' \
  'stable.priorityOnly=A,C,B,D' \
  'nullsLast.dueAt=WO-201,WO-203,WO-202' \
  'source.unchanged=WO-103,WO-101,WO-104,WO-102' \
  'contract.signReverse=true' > "$BUILD_DIR/expected.out"
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

set +e
java -cp "$CLASSES_DIR" SubtractionOverflowFailure > "$BUILD_DIR/failure.out" 2> "$BUILD_DIR/failure.err"
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
grep -Fq 'OVERFLOW_ORDER' "$BUILD_DIR/failure.err"

cat "$BUILD_DIR/demo.out"
printf 'EXPECTED_RUNTIME_FAILURE SubtractionOverflowFailure status=%s evidence=OVERFLOW_ORDER\n' "$failure_status"
printf 'EXAMPLE PASS lines=8 runtime_failures=1 warnings=0 jdk=25\n'
