#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "EXPECTED java 25" >&2; exit 2 ;; esac
case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "EXPECTED javac 25" >&2; exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$ROOT_DIR/src/WorkflowStateSlaFaultLab.java"
java -cp "$BUILD_DIR/classes" WorkflowStateSlaFaultLab > "$BUILD_DIR/actual.out"
cmp -s "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out" || {
  diff -u "$ROOT_DIR/expected.out" "$BUILD_DIR/actual.out"
  exit 1
}

FAULTS=(JUMP_ALLOWED MUTATE_BEFORE_VALIDATE GUARD_SKIPPED TERMINAL_REVIVED SYSTEM_CLOCK LOCAL_TIME_DEADLINE PAUSE_DOUBLE_COUNT)
ORACLES=(JUMP_STATE_ACCEPTED INVALID_TRANSITION_MUTATED_STATE MISSING_GUARD_ACCEPTED TERMINAL_STATE_REVIVED SYSTEM_CLOCK_DRIFTED DST_DEADLINE_DRIFTED PAUSE_WINDOW_DOUBLE_COUNTED)
for index in "${!FAULTS[@]}"; do
  actual="$(java -cp "$BUILD_DIR/classes" WorkflowStateSlaFaultLab "${FAULTS[$index]}")"
  if [[ "$actual" != "${ORACLES[$index]}" ]]; then
    echo "fault ${FAULTS[$index]} did not expose ${ORACLES[$index]}: $actual" >&2
    exit 1
  fi
done

if rg -n '(java\.net|HttpClient|Socket|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY)' "$ROOT_DIR/src"; then
  echo "network primitive or secret material found" >&2
  exit 1
fi
echo "LAB PASS jdk=25 mode=offline fault_oracles=7"
