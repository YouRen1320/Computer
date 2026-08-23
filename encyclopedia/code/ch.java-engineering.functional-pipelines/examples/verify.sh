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
java -cp "$CLASSES_DIR" FunctionalPipelinesDemo > "$BUILD_DIR/demo.out"
printf '%s\n' \
  'lazy.before=0' \
  'lazy.after=5' \
  'open.ids=WO-101,WO-103,WO-104,WO-105' \
  'group.minutes=MECHANICAL:55,ELECTRICAL:20,NETWORK:40' \
  'reduce.total=115' \
  'optional.max=5' \
  'optional.emptyFallback=0' \
  'source.unchanged=true' > "$BUILD_DIR/expected.out"
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

set +e
java -cp "$CLASSES_DIR" ReusedStreamFailure > "$BUILD_DIR/failure.out" 2> "$BUILD_DIR/failure.err"
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
grep -Fq 'REUSED_STREAM' "$BUILD_DIR/failure.err"

cat "$BUILD_DIR/demo.out"
printf 'EXPECTED_RUNTIME_FAILURE ReusedStreamFailure status=%s evidence=REUSED_STREAM\n' "$failure_status"
printf 'EXAMPLE PASS lines=8 runtime_failures=1 warnings=0 jdk=25\n'
