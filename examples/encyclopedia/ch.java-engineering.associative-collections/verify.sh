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
java -cp "$CLASSES_DIR" AssociativeCollectionsDemo > "$BUILD_DIR/demo.out"
printf '%s\n' \
  'input.rows=3' \
  'input.ids=PUMP-01,FAN-02,PUMP-01' \
  'unique.size=2' \
  'unique.ids=PUMP-01,FAN-02' \
  'category.counts=pump:2,fan:1' \
  'map.equalKey.hit=true' \
  'map.equalKey.state=OPEN' \
  'missing.contains=false' \
  'missing.get=null' \
  'sorted.ids=FAN-02,PUMP-01' > "$BUILD_DIR/expected.out"
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

set +e
java -cp "$CLASSES_DIR" MutableHashKeyFailure > "$BUILD_DIR/failure.out" 2> "$BUILD_DIR/failure.err"
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
grep -Fq 'LOST_HASH_KEY' "$BUILD_DIR/failure.err"

cat "$BUILD_DIR/demo.out"
printf 'EXPECTED_RUNTIME_FAILURE MutableHashKeyFailure status=%s evidence=LOST_HASH_KEY\n' "$failure_status"
printf 'EXAMPLE PASS lines=10 runtime_failures=1 warnings=0 jdk=25\n'
