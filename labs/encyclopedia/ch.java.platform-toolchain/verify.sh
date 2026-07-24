#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/factorycare-toolchain-lab.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

SOURCE_FILE="$ROOT_DIR/starter/src/com/factorycare/learning/ToolchainProbe.java"
MAIN_CLASS="com.factorycare.learning.ToolchainProbe"
CLASSES_DIR="$WORK_DIR/classes"
EMPTY_DIR="$WORK_DIR/empty"
mkdir -p "$CLASSES_DIR" "$EMPTY_DIR"

JAVA_PATH="$(command -v java)"
JAVAC_PATH="$(command -v javac)"
JAVA_VERSION="$($JAVA_PATH -version 2>&1 | head -n 1)"
JAVAC_VERSION="$($JAVAC_PATH -version 2>&1 | head -n 1)"
case "$JAVA_VERSION" in
  *'version "25.'*|*'version "25"'*) ;;
  *) echo "FAIL: this lab requires java 25.x, got: $JAVA_VERSION" >&2; exit 2 ;;
esac
case "$JAVAC_VERSION" in
  "javac 25"*) ;;
  *) echo "FAIL: this lab requires javac 25.x, got: $JAVAC_VERSION" >&2; exit 2 ;;
esac

"$JAVAC_PATH" --release 25 -encoding UTF-8 -d "$CLASSES_DIR" "$SOURCE_FILE"
CLASS_FILE="$CLASSES_DIR/com/factorycare/learning/ToolchainProbe.class"
test -s "$CLASS_FILE"

JAVAP_PATH="${JAVAC_PATH%/javac}/javap"
MAJOR_VERSION="$($JAVAP_PATH -classpath "$CLASSES_DIR" -verbose "$MAIN_CLASS" | awk '/major version:/ {print $3; exit}')"
test "$MAJOR_VERSION" = "69"

"$JAVA_PATH" -cp "$CLASSES_DIR" "$MAIN_CLASS" >"$WORK_DIR/actual.txt" 2>"$WORK_DIR/run.stderr"
printf '%s\n' 'FactoryCare probe READY' >"$WORK_DIR/expected.txt"
diff -u "$WORK_DIR/expected.txt" "$WORK_DIR/actual.txt"
test ! -s "$WORK_DIR/run.stderr"

set +e
"$JAVAC_PATH" --release 99 -d "$CLASSES_DIR" "$SOURCE_FILE" >"$WORK_DIR/bad-release.stdout" 2>"$WORK_DIR/bad-release.stderr"
BAD_RELEASE_EXIT=$?
"$JAVA_PATH" -cp "$EMPTY_DIR" "$MAIN_CLASS" >"$WORK_DIR/bad-classpath.stdout" 2>"$WORK_DIR/bad-classpath.stderr"
BAD_CLASSPATH_EXIT=$?
set -e

test "$BAD_RELEASE_EXIT" -ne 0
grep -Fq '99' "$WORK_DIR/bad-release.stderr"
test "$BAD_CLASSPATH_EXIT" -ne 0
grep -Fq "$MAIN_CLASS" "$WORK_DIR/bad-classpath.stderr"

echo "LAB_GREEN: compile=0 run=0 major=$MAJOR_VERSION bad_release=$BAD_RELEASE_EXIT bad_classpath=$BAD_CLASSPATH_EXIT"
