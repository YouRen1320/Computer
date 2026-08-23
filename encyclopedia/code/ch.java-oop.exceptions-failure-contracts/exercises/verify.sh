#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
FAILURE_CLASSES="$BUILD_DIR/failure-classes"
STARTER_SOURCE_SHA256="967945fc429e9149ac2b942bf0aebc7f5ffea67a71c5796fecca70bacd636403"

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
  echo "UNKNOWN_STATE chapter=ch.java-oop.exceptions-failure-contracts phase=starter-fingerprint" >&2
  exit 43
fi
starter_sources_match=0
if [[ "$current_source_sha256" == "$STARTER_SOURCE_SHA256" ]]; then
  starter_sources_match=1
fi

case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "UNKNOWN_STATE expected=javac-25" >&2; exit 43 ;; esac
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "UNKNOWN_STATE expected=java-25" >&2; exit 43 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR" "$FAILURE_CLASSES" "$BUILD_DIR/failure-src"
set +e
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/ExceptionContractChallenge.java" "$ROOT_DIR/failures/SwallowedFailure.java" >"$BUILD_DIR/compile.out" 2>"$BUILD_DIR/compile.err"
compile_status=$?
set -e
if [[ $compile_status -ne 0 ]]; then
  cat "$BUILD_DIR/compile.err" >&2
  echo "UNKNOWN_STATE chapter=ch.java-oop.exceptions-failure-contracts phase=compile" >&2
  exit 43
fi

cp "$ROOT_DIR/failures/UnhandledCheckedFailure.java.txt" "$BUILD_DIR/failure-src/UnhandledCheckedFailure.java"
set +e
javac -XDrawDiagnostics --release 25 -d "$FAILURE_CLASSES" "$BUILD_DIR/failure-src/UnhandledCheckedFailure.java" >"$BUILD_DIR/checked.out" 2>"$BUILD_DIR/checked.err"
checked_status=$?
java -cp "$CLASSES_DIR" SwallowedFailure >"$BUILD_DIR/swallow.out" 2>"$BUILD_DIR/swallow.err"
swallow_status=$?
java -cp "$CLASSES_DIR" ExceptionContractChallenge >"$BUILD_DIR/challenge.out" 2>"$BUILD_DIR/challenge.err"
challenge_status=$?
set -e

if [[ $checked_status -eq 0 ]] \
    || ! grep -Fq "compiler.err.unreported.exception.need.to.catch.or.throw" "$BUILD_DIR/checked.err" \
    || [[ $swallow_status -ne 4 ]] \
    || ! grep -Fqx "SWALLOWED_FAILURE result=null causeLost=true" "$BUILD_DIR/swallow.err"; then
  cat "$BUILD_DIR/checked.err" "$BUILD_DIR/swallow.out" "$BUILD_DIR/swallow.err" >&2
  echo "UNKNOWN_STATE chapter=ch.java-oop.exceptions-failure-contracts fixture-contract" >&2
  exit 43
fi

if [[ $challenge_status -eq 0 ]] \
    && [[ ! -s "$BUILD_DIR/challenge.err" ]] \
    && grep -Fqx "challenge.assertions=10 passed" "$BUILD_DIR/challenge.out"; then
  cat "$BUILD_DIR/challenge.out"
  echo "EXERCISE_GREEN chapter=ch.java-oop.exceptions-failure-contracts assertions=10 fixtures=preserved"
  exit 0
fi

if [[ $starter_sources_match -eq 1 ]] \
    && [[ $challenge_status -eq 8 ]] \
    && [[ ! -s "$BUILD_DIR/challenge.out" ]] \
    && grep -Fqx "STARTER_INPUT_MISCLASSIFIED expected=INVALID_INPUT actual=SYSTEM_ERROR:cause=missing" "$BUILD_DIR/challenge.err"; then
  echo "EXPECTED_RED chapter=ch.java-oop.exceptions-failure-contracts first=STARTER_INPUT_MISCLASSIFIED status=8"
  exit 41
fi

cat "$BUILD_DIR/challenge.out" "$BUILD_DIR/challenge.err" >&2
echo "UNKNOWN_STATE chapter=ch.java-oop.exceptions-failure-contracts phase=challenge status=$challenge_status" >&2
exit 43
