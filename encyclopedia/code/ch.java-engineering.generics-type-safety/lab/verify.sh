#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
JAVAC_VERSION="$(javac -version 2>&1)"
case "$JAVAC_VERSION" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java
java -cp "$CLASSES_DIR" GenericSafetyOracle > "$BUILD_DIR/lab.out"
grep -Fqx 'report.input=RepairTicket[WO-201,WO-202]' "$BUILD_DIR/lab.out"
grep -Fqx 'report.operation=copy extends-to-super' "$BUILD_DIR/lab.out"
grep -Fqx 'report.result=WorkItem[WO-201,WO-202,IN-301]' "$BUILD_DIR/lab.out"
grep -Fqx 'assertions=12 passed' "$BUILD_DIR/lab.out"

failure_count=0
for source in "$ROOT_DIR"/failures/*.java; do
    name="$(basename "$source" .java)"
    set +e
    javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$source" > "$BUILD_DIR/$name.out" 2> "$BUILD_DIR/$name.err"
    status=$?
    set -e
    [[ $status -ne 0 ]]
    grep -Fq "$(basename "$source")" "$BUILD_DIR/$name.err"
    failure_count=$((failure_count + 1))
    printf 'EXPECTED_COMPILE_FAILURE %s status=%s\n' "$name" "$status"
done
[[ $failure_count -eq 4 ]]

cat "$BUILD_DIR/lab.out"
printf 'LAB PASS assertions=12 compile_failures=4 warnings=0 jdk=25\n'
