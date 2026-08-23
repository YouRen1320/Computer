#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBMISSION_DIR="$ROOT_DIR/submission"
SOURCE_FILE="$SUBMISSION_DIR/src/com/factorycare/learning/InspectionSnapshot.java"
EXPECTED_FILE="$SUBMISSION_DIR/expected-output.txt"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/factorycare-values-exercise.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

if [[ ! -f "$SOURCE_FILE" || ! -f "$EXPECTED_FILE" ]]; then
  echo "EXPECTED_RED: add submission/src/com/factorycare/learning/InspectionSnapshot.java and submission/expected-output.txt."
  exit 41
fi
case "$(javac -version 2>&1 | head -n 1)" in "javac 25"*) ;; *) echo "UNEXPECTED_ENVIRONMENT: javac 25.x required" >&2; exit 2 ;; esac
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "UNEXPECTED_ENVIRONMENT: java 25.x required" >&2; exit 2 ;; esac

for required in '900000001L' 'C区-配电柜-03' '待提交' '已提交' '现场检查'; do
  if ! grep -Fq "$required" "$SOURCE_FILE"; then
    echo "EXPECTED_RED: source is missing required value: $required"
    exit 41
  fi
done
for output_method in 'System.out.print(' 'System.out.println(' 'System.out.printf('; do
  if ! grep -Fq "$output_method" "$SOURCE_FILE"; then
    echo "EXPECTED_RED: source must use $output_method"
    exit 41
  fi
done

mkdir -p "$WORK_DIR/classes"
if ! javac --release 25 -encoding UTF-8 -d "$WORK_DIR/classes" "$SOURCE_FILE"; then
  echo "EXPECTED_RED: InspectionSnapshot does not compile yet."
  exit 41
fi
if ! java -cp "$WORK_DIR/classes" com.factorycare.learning.InspectionSnapshot >"$WORK_DIR/actual.txt"; then
  echo "EXPECTED_RED: InspectionSnapshot does not run successfully yet."
  exit 41
fi
if ! diff -u "$EXPECTED_FILE" "$WORK_DIR/actual.txt"; then
  echo "EXPECTED_RED: actual output differs from the prediction saved before running."
  exit 41
fi
for visible_value in '900000001' 'C区-配电柜-03' '1' 'true' 'C' '已提交' '现场检查'; do
  if ! grep -Fq "$visible_value" "$WORK_DIR/actual.txt"; then
    echo "EXPECTED_RED: output does not expose required value: $visible_value"
    exit 41
  fi
done

echo "EXERCISE_GREEN: required values, output APIs, compilation, and exact output comparison are verified."
