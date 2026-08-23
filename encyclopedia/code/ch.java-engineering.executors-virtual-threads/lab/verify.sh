#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
BUILD=$(mktemp -d "${TMPDIR:-/tmp}/fc-executors-lab.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT

case "$(javac -version 2>&1)" in
  "javac 25"*) ;;
  *) echo "JDK 25 javac required" >&2; exit 2 ;;
esac

javac --release 25 -d "$BUILD" "$ROOT/src/ExecutorLifecycleOracle.java"
actual=$(java -cp "$BUILD" ExecutorLifecycleOracle)
expected='success-result=WO-201:READY
failure-cause=IllegalArgumentException:unknown-device
shutdown-rejects=true,workers-alive=0
timeout-observed=true,cancelled=true,interrupt-observed=true
ignored-interrupt-cancelled=true,terminated-before-release=false,terminated-after-release=true
virtual-tasks=6,all-virtual=true,max-resource-use=2
virtual-shared-race=1,atomic=2
executor-lifecycle-oracle=PASS'

if [[ "$actual" != "$expected" ]]; then
  printf 'unexpected output:\n%s\n' "$actual" >&2
  exit 1
fi

printf '%s\n' "$actual"
