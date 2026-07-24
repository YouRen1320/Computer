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
java -cp "$CLASSES_DIR" JsonMappingDemo "$BUILD_DIR/work-order.json" > "$BUILD_DIR/demo.out"
printf '%s\n' \
  'json={"schemaVersion":1,"id":"WO-机泵-101","status":"CREATED","openedAt":"2026-07-16T01:30:00Z","amount":1234.50,"assignee":null}' \
  'roundtrip.equal=true' \
  'assignee.presence=EXPLICIT_NULL' \
  'unknown.lenient.id=WO-机泵-101' \
  'strict.unknown=UNKNOWN_FIELD:priorityLabel' \
  'time.instant=2026-07-16T01:30:00Z' \
  'amount.plain=1234.50' \
  'file.utf8=true' > "$BUILD_DIR/expected.out"
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

set +e
java -cp "$CLASSES_DIR" InvalidEnumFailure > "$BUILD_DIR/failure.out" 2> "$BUILD_DIR/failure.err"
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
grep -Fq 'INVALID_ENUM:status' "$BUILD_DIR/failure.err"

cat "$BUILD_DIR/demo.out"
printf 'EXPECTED_RUNTIME_FAILURE InvalidEnumFailure status=%s evidence=INVALID_ENUM:status\n' "$failure_status"
printf 'EXAMPLE PASS lines=8 runtime_failures=1 warnings=0 jdk=25\n'
