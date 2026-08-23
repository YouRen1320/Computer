#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_FILE="$ROOT_DIR/submission/src/com/factorycare/learning/RepairIntake.java"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/factorycare-program-exercise.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "EXPECTED_RED: create submission/src/com/factorycare/learning/RepairIntake.java from the independent-build contract."
  exit 41
fi
case "$(javac -version 2>&1 | head -n 1)" in "javac 25"*) ;; *) echo "UNEXPECTED_ENVIRONMENT: javac 25.x required" >&2; exit 2 ;; esac
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "UNEXPECTED_ENVIRONMENT: java 25.x required" >&2; exit 2 ;; esac

if ! grep -Fq '//' "$SOURCE_FILE" || ! grep -Fq '/*' "$SOURCE_FILE"; then
  echo "EXPECTED_RED: the source must contain both // and /* ... */ comments."
  exit 41
fi

mkdir -p "$WORK_DIR/classes"
if ! javac --release 25 -encoding UTF-8 -d "$WORK_DIR/classes" "$SOURCE_FILE"; then
  echo "EXPECTED_RED: the independent source does not compile yet."
  exit 41
fi
if ! java -cp "$WORK_DIR/classes" com.factorycare.learning.RepairIntake >"$WORK_DIR/actual.txt"; then
  echo "EXPECTED_RED: the compiled class does not run successfully yet."
  exit 41
fi
printf '%s\n' 'repair intake' 'FactoryCare' 'ready' >"$WORK_DIR/expected.txt"
if ! diff -u "$WORK_DIR/expected.txt" "$WORK_DIR/actual.txt"; then
  echo "EXPECTED_RED: runtime output does not match the three-line oracle."
  exit 41
fi

echo "EXERCISE_GREEN: independent source compiles, runs, and matches its structure/output contract."
