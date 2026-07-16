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
mkdir -p "$CLASSES_DIR" "$BUILD_DIR/failures"
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR/src/GenericTypeDemo.java"
java -cp "$CLASSES_DIR" GenericTypeDemo > "$BUILD_DIR/demo.out"
printf '%s\n' \
  'result.type=Device' \
  'result.id=PUMP-01' \
  'workItems.size=2' \
  'workItems.first=WO-101' \
  'auditItems.size=2' \
  'same.reference=true' > "$BUILD_DIR/expected.out"
cmp -s "$BUILD_DIR/expected.out" "$BUILD_DIR/demo.out"

for name in InvarianceFailure ExtendsWriteFailure; do
    cp "$ROOT_DIR/failures/$name.java.txt" "$BUILD_DIR/failures/$name.java"
    set +e
    javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$BUILD_DIR/failures/$name.java" > "$BUILD_DIR/$name.out" 2> "$BUILD_DIR/$name.err"
    status=$?
    set -e
    [[ $status -ne 0 ]]
    grep -Fq "$name.java" "$BUILD_DIR/$name.err"
    printf 'EXPECTED_COMPILE_FAILURE %s status=%s\n' "$name" "$status"
done

set +e
javac --release 25 -Xlint:rawtypes,unchecked -d "$CLASSES_DIR" "$ROOT_DIR/src/RawTypeRuntimeFailure.java" > "$BUILD_DIR/raw-compile.out" 2> "$BUILD_DIR/raw-compile.err"
raw_compile_status=$?
set -e
[[ $raw_compile_status -eq 0 ]]
grep -Eqi 'warning|警告|rawtypes|unchecked' "$BUILD_DIR/raw-compile.err"
set +e
java -cp "$CLASSES_DIR" RawTypeRuntimeFailure > "$BUILD_DIR/raw.out" 2> "$BUILD_DIR/raw.err"
raw_status=$?
set -e
[[ $raw_status -ne 0 ]]
grep -Fq 'ClassCastException' "$BUILD_DIR/raw.err"

cat "$BUILD_DIR/demo.out"
printf 'EXPECTED_RUNTIME_FAILURE RawTypeRuntimeFailure status=%s evidence=ClassCastException\n' "$raw_status"
printf 'EXAMPLE PASS lines=6 compile_failures=2 raw_warnings=true jdk=25\n'
