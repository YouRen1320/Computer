#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
BUILD=$(mktemp -d "${TMPDIR:-/tmp}/fc-executors-exercise.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT

case "$(javac -version 2>&1)" in
  "javac 25"*) ;;
  *) echo "JDK 25 javac required" >&2; exit 2 ;;
esac

javac --release 25 -d "$BUILD" "$ROOT/src/ExecutorChallenge.java"
set +e
actual=$(java -cp "$BUILD" ExecutorChallenge 2>&1)
status=$?
set -e

expected='starter-failure=expected cause-preserved actual=UNKNOWN'
if [[ $status -ne 1 || "$actual" != "$expected" ]]; then
  printf 'starter no longer exposes the expected red oracle:\n%s\n' "$actual" >&2
  exit 1
fi

printf '%s\n' "$actual"
echo 'exercise-starter=EXPECTED-FAIL'
exit 41
