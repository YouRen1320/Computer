#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/program-structure-solution.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

mkdir -p "$WORK/classes"
javac --release 25 -encoding UTF-8 \
    -d "$WORK/classes" \
    "$ROOT/src/com/factorycare/learning/RepairIntake.java"
java -cp "$WORK/classes" com.factorycare.learning.RepairIntake > "$WORK/actual.txt"
diff -u "$ROOT/expected-output.txt" "$WORK/actual.txt"
echo "PASS: private reference solution matches the exercise oracle."
