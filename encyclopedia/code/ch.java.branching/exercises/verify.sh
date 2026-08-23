#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/factorycare-branching-exercise.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM
case "$(javac -version 2>&1 | head -n 1)" in "javac 25"*) ;; *) echo "UNEXPECTED_ENVIRONMENT: javac 25.x required" >&2; exit 2 ;; esac
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "UNEXPECTED_ENVIRONMENT: java 25.x required" >&2; exit 2 ;; esac

mkdir -p "$WORK_DIR/classes"
if ! javac --release 25 -encoding UTF-8 -d "$WORK_DIR/classes" "$ROOT_DIR/src/TicketRoutingChallenge.java"; then
  echo "UNEXPECTED_BUILD_FAILURE: starter and completed exercise must remain compilable." >&2
  exit 42
fi
if ! java -cp "$WORK_DIR/classes" TicketRoutingChallenge >"$WORK_DIR/actual.txt"; then
  echo "UNEXPECTED_RUNTIME_FAILURE: compiled exercise did not finish normally." >&2
  exit 43
fi
printf '%s\n' 'priority.1=ROUTINE' 'priority.3=HIGH' 'priority.5=CRITICAL' 'priority.0=REJECTED' 'status.ASSIGNED=WORK' >"$WORK_DIR/expected.txt"
if ! diff -u --label expected --label actual "$WORK_DIR/expected.txt" "$WORK_DIR/actual.txt"; then
  echo "EXPECTED_RED: repair the lower boundary, critical boundary, and ASSIGNED switch arm."
  exit 41
fi

echo "EXERCISE_GREEN: all boundary and switch-expression oracles match."
