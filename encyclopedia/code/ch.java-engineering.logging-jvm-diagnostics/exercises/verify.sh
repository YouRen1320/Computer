#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
STARTER_SOURCE_SHA256="fca559da33f13e8e2b878e961a1100310ae8e1135f8912b2c757d8e2aa619eb8"

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
    relative=${file#"$ROOT_DIR/"}
    digest="$(sha256_stream <"$file")" || return $?
    manifest="${manifest}${relative}:${digest}"$'\n'
  done < <(find "$ROOT_DIR/src" -type f -print | LC_ALL=C sort)
  [[ -n "$manifest" ]] || return 1
  printf '%s' "$manifest" | sha256_stream
}

if ! current_source_sha256="$(source_tree_sha256)"; then
  echo "UNKNOWN_STATE chapter=ch.java-engineering.logging-jvm-diagnostics phase=starter-fingerprint" >&2
  exit 43
fi
starter_sources_match=0
if [[ "$current_source_sha256" == "$STARTER_SOURCE_SHA256" ]]; then
  starter_sources_match=1
fi

case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "UNKNOWN_STATE expected=javac-25" >&2; exit 43 ;; esac
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "UNKNOWN_STATE expected=java-25" >&2; exit 43 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
set +e
javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR" "$ROOT_DIR/src/DiagnosticsChallenge.java" >"$BUILD_DIR/compile.out" 2>"$BUILD_DIR/compile.err"
compile_status=$?
set -e
if [[ $compile_status -ne 0 ]]; then
  cat "$BUILD_DIR/compile.err" >&2
  echo "UNKNOWN_STATE chapter=ch.java-engineering.logging-jvm-diagnostics phase=compile" >&2
  exit 43
fi

set +e
java -cp "$BUILD_DIR" DiagnosticsChallenge >"$BUILD_DIR/challenge.out" 2>"$BUILD_DIR/challenge.err"
status=$?
set -e
actual=$(cat "$BUILD_DIR/challenge.out")
expected_green='redaction=true correlation=true thread_series=true performance_gate=true
EXERCISE PASS jdk=25'
todo_count=$(grep -c 'TODO' "$ROOT_DIR/src/DiagnosticsChallenge.java" || true)

if [[ $status -eq 0 ]] \
    && [[ ! -s "$BUILD_DIR/challenge.err" ]] \
    && [[ "$actual" == "$expected_green" ]] \
    && [[ $todo_count -eq 0 ]]; then
  printf '%s\n' "$actual"
  echo "EXERCISE_GREEN chapter=ch.java-engineering.logging-jvm-diagnostics policies=4"
  exit 0
fi

if [[ $starter_sources_match -eq 1 ]] \
    && [[ $status -eq 1 ]] \
    && [[ ! -s "$BUILD_DIR/challenge.out" ]] \
    && grep -Fq 'SECRET_NOT_REDACTED' "$BUILD_DIR/challenge.err" \
    && [[ $todo_count -eq 4 ]]; then
  echo "EXPECTED_RED chapter=ch.java-engineering.logging-jvm-diagnostics first=SECRET_NOT_REDACTED todos=4"
  exit 41
fi

cat "$BUILD_DIR/challenge.out" "$BUILD_DIR/challenge.err" >&2
echo "UNKNOWN_STATE chapter=ch.java-engineering.logging-jvm-diagnostics phase=challenge status=$status todos=$todo_count" >&2
exit 43
