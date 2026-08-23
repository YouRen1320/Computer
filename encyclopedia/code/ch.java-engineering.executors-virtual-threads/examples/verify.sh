#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
BUILD=$(mktemp -d "${TMPDIR:-/tmp}/fc-executors-example.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT

case "$(javac -version 2>&1)" in
  "javac 25"*) ;;
  *) echo "JDK 25 javac required" >&2; exit 2 ;;
esac

javac --release 25 -d "$BUILD" "$ROOT/src/ExecutorsVirtualThreadsDemo.java"
actual=$(java -cp "$BUILD" ExecutorsVirtualThreadsDemo)
expected='success=WO-101:READY
failure=IllegalStateException:device-offline
timeout=TimeoutException
cancel-requested=true,state=CANCELLED
fixed-terminated=true
virtual=true
virtual-terminated=true'

if [[ "$actual" != "$expected" ]]; then
  printf 'unexpected output:\n%s\n' "$actual" >&2
  exit 1
fi

printf '%s\n' "$actual"
echo 'example-verification=PASS'
