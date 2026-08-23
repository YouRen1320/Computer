#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_FILE="$ROOT_DIR/submission/src/com/example/App.java"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/factorycare-toolchain-exercise.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "EXPECTED_RED: create submission/src/com/example/App.java, then make it print FactoryCare and READY on two lines."
  exit 41
fi

JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
JAVAC_VERSION="$(javac -version 2>&1 | head -n 1)"
case "$JAVA_VERSION" in *'version "25.'*|*'version "25"'*) ;; *) echo "UNEXPECTED_ENVIRONMENT: java 25.x required" >&2; exit 2 ;; esac
case "$JAVAC_VERSION" in "javac 25"*) ;; *) echo "UNEXPECTED_ENVIRONMENT: javac 25.x required" >&2; exit 2 ;; esac

mkdir -p "$WORK_DIR/classes"
if ! javac --release 25 -encoding UTF-8 -d "$WORK_DIR/classes" "$SOURCE_FILE"; then
  echo "EXPECTED_RED: submission does not compile yet."
  exit 41
fi

CLASS_FILE="$WORK_DIR/classes/com/example/App.class"
if [[ ! -s "$CLASS_FILE" ]]; then
  echo "EXPECTED_RED: package, source path, and class name must produce com/example/App.class."
  exit 41
fi

if ! java -cp "$WORK_DIR/classes" com.example.App >"$WORK_DIR/actual.txt"; then
  echo "EXPECTED_RED: compiled class does not run successfully yet."
  exit 41
fi
printf '%s\n' 'FactoryCare' 'READY' >"$WORK_DIR/expected.txt"
if ! diff -u "$WORK_DIR/expected.txt" "$WORK_DIR/actual.txt"; then
  echo "EXPECTED_RED: final two-line output does not match the changed requirement."
  exit 41
fi

MAJOR_VERSION="$(javap -classpath "$WORK_DIR/classes" -verbose com.example.App | awk '/major version:/ {print $3; exit}')"
if [[ "$MAJOR_VERSION" != "69" ]]; then
  echo "EXPECTED_RED: class major version must be 69, got $MAJOR_VERSION."
  exit 41
fi

echo "EXERCISE_GREEN: source, package path, JDK 25 class version, and final output all match."
