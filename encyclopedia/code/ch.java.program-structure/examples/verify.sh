#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/program-structure-example.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

JAVAC=${JAVAC:-javac}
JAVA=${JAVA:-java}
SOURCE="$ROOT/src/com/factorycare/learning/ProgramStructureDemo.java"
CLASS_FILE="$WORK/classes/com/factorycare/learning/ProgramStructureDemo.class"

case "$("$JAVAC" -version 2>&1 | head -n 1)" in
    "javac 25"*) ;;
    *) echo "FAIL: this example requires javac 25.x" >&2; exit 2 ;;
esac
case "$("$JAVA" -version 2>&1 | head -n 1)" in
    *'version "25.'*|*'version "25"'*) ;;
    *) echo "FAIL: this example requires java 25.x" >&2; exit 2 ;;
esac

mkdir -p "$WORK/classes"
"$JAVAC" --release 25 -encoding UTF-8 -d "$WORK/classes" "$SOURCE"

if [ ! -f "$CLASS_FILE" ]; then
    echo "FAIL: javac did not create the class file at the package path" >&2
    exit 1
fi

"$JAVA" -cp "$WORK/classes" com.factorycare.learning.ProgramStructureDemo > "$WORK/actual.txt"

if ! diff -u "$ROOT/expected-output.txt" "$WORK/actual.txt"; then
    echo "FAIL: runtime output differs from the chapter oracle" >&2
    exit 1
fi

echo "PASS: source compiled, package path exists, and output matches."
