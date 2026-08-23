#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
BUILD=$(mktemp -d "${TMPDIR:-/tmp}/fc-executors-solution.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT

case "$(javac -version 2>&1)" in
  "javac 25"*) ;;
  *) echo "JDK 25 javac required" >&2; exit 2 ;;
esac

javac --release 25 -d "$BUILD" "$ROOT/src/ExecutorChallengeSolution.java"
actual=$(java -cp "$BUILD" ExecutorChallengeSolution)
expected='result=WO-301:READY
failure=IllegalStateException:device-offline
virtual=true
timeout=true,cancelled=true
terminated=true,rejectedAfterClose=true
challenge=PASS'

if [[ "$actual" != "$expected" ]]; then
  printf 'unexpected output:\n%s\n' "$actual" >&2
  exit 1
fi

printf '%s\n' "$actual"
