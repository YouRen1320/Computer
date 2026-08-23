#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
BUILD=$(mktemp -d "${TMPDIR:-/tmp}/fc-executors-exercise.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT
STARTER_SOURCE_SHA256="1b7b616ca67d0153ab144c9868970586f9da603a9c33b2ea526ae99038e56ce5"

sha256_stream() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    return 127
  fi
}

source_tree_sha256() {
  local file relative digest manifest=""
  while IFS= read -r file; do
    relative=${file#"$ROOT/"}
    digest="$(sha256_stream <"$file")" || return $?
    manifest="${manifest}${relative}:${digest}"$'\n'
  done < <(find "$ROOT/src" -type f -print | LC_ALL=C sort)
  [[ -n "$manifest" ]] || return 1
  printf '%s' "$manifest" | sha256_stream
}

if ! current_source_sha256="$(source_tree_sha256)"; then
  echo "UNKNOWN_STATE chapter=ch.java-engineering.executors-virtual-threads phase=starter-fingerprint" >&2
  exit 43
fi
starter_sources_match=0
if [[ "$current_source_sha256" == "$STARTER_SOURCE_SHA256" ]]; then
  starter_sources_match=1
fi

case "$(javac -version 2>&1)" in
  "javac 25"*) ;;
  *) echo "UNKNOWN_STATE expected=javac-25" >&2; exit 43 ;;
esac
case "$(java -version 2>&1 | head -n 1)" in
  *'version "25.'*|*'version "25"'*) ;;
  *) echo "UNKNOWN_STATE expected=java-25" >&2; exit 43 ;;
esac

set +e
javac --release 25 -Xlint:all -Werror -d "$BUILD" "$ROOT/src/ExecutorChallenge.java" >"$BUILD/compile.out" 2>"$BUILD/compile.err"
compile_status=$?
set -e
if [[ $compile_status -ne 0 ]]; then
  cat "$BUILD/compile.err" >&2
  echo "UNKNOWN_STATE chapter=ch.java-engineering.executors-virtual-threads phase=compile" >&2
  exit 43
fi

set +e
java -cp "$BUILD" ExecutorChallenge >"$BUILD/challenge.out" 2>"$BUILD/challenge.err"
status=$?
set -e

expected_green='result=WO-301:READY
failure=IllegalStateException:device-offline
virtual=true
timeout=true,cancelled=true
terminated=true,rejectedAfterClose=true
challenge=PASS'
actual=$(cat "$BUILD/challenge.out")

if [[ $status -eq 0 ]] && [[ ! -s "$BUILD/challenge.err" ]] && [[ "$actual" == "$expected_green" ]]; then
  printf '%s\n' "$actual"
  echo "EXERCISE_GREEN chapter=ch.java-engineering.executors-virtual-threads contracts=failure,timeout,cancel,lifecycle"
  exit 0
fi

if [[ $starter_sources_match -eq 1 ]] \
    && [[ $status -eq 1 ]] \
    && [[ ! -s "$BUILD/challenge.err" ]] \
    && [[ "$actual" == 'starter-failure=expected cause-preserved actual=UNKNOWN' ]]; then
  printf '%s\n' "$actual"
  echo "EXPECTED_RED chapter=ch.java-engineering.executors-virtual-threads first=cause-not-preserved status=1"
  exit 41
fi

cat "$BUILD/challenge.out" "$BUILD/challenge.err" >&2
echo "UNKNOWN_STATE chapter=ch.java-engineering.executors-virtual-threads phase=challenge status=$status" >&2
exit 43
