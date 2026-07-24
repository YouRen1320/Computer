#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C LANG=C
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBMISSION_FILE="$ROOT_DIR/submission.md"
if [[ ! -f "$SUBMISSION_FILE" ]]; then
  echo "EXPECTED_RED submission.md is missing; record the six-case prediction and rewrite evidence" >&2
  exit 41
fi
for heading in "## 六例预测" "## 重写说明"; do
  if ! grep -Fq "$heading" "$SUBMISSION_FILE"; then
    echo "EXPECTED_RED submission.md is missing section: $heading" >&2
    exit 41
  fi
done
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/RepairIntakeCli.java"

check() {
  local name="$1" expected="$2" stream="$3" input="$4"; shift 4
  set +e
  printf '%s' "$input" | java -cp "$CLASSES_DIR" RepairIntakeCli "$@" > "$BUILD_DIR/$name.out" 2> "$BUILD_DIR/$name.err"
  local status=$?
  set -e
  [[ $status -eq $expected ]]
  [[ "$stream" == stdout ]] && [[ -s "$BUILD_DIR/$name.out" && ! -s "$BUILD_DIR/$name.err" ]]
  [[ "$stream" == stderr ]] && [[ ! -s "$BUILD_DIR/$name.out" && -s "$BUILD_DIR/$name.err" ]]
  echo "CASE $name status=$status channel=$stream"
}
check args 0 stdout "" 5 "motor alarm"
check stdin 0 stdout $'3 temperature high\n'
check usage 64 stderr "" 3
check invalid-number 65 stderr "" x alarm
check invalid-range 65 stderr "" 6 alarm
check eof 66 stderr ""
echo "EXERCISE PASS repair-intake cases=6"
