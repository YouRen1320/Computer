#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
STARTER_SOURCE_SHA256="837472f45ffe0a0568d2db2477ed761d7b741308b5c9e07d7acd4206e7e04668"

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
  echo "UNKNOWN_STATE chapter=ch.java-oop.business-value-types phase=starter-fingerprint" >&2
  exit 43
fi
starter_sources_match=0
if [[ "$current_source_sha256" == "$STARTER_SOURCE_SHA256" ]]; then
  starter_sources_match=1
fi

case "$(javac -version 2>&1)" in "javac 25"|"javac 25."*) ;; *) echo "UNKNOWN_STATE expected=javac-25" >&2; exit 43 ;; esac
case "$(java -version 2>&1 | head -n 1)" in *'version "25.'*|*'version "25"'*) ;; *) echo "UNKNOWN_STATE expected=java-25" >&2; exit 43 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$CLASSES_DIR"
set +e
javac --release 25 -d "$CLASSES_DIR" "$ROOT_DIR/src/BusinessValueChallenge.java" "$ROOT_DIR/failures/LooseRegexFailure.java" >"$BUILD_DIR/compile.out" 2>"$BUILD_DIR/compile.err"
compile_status=$?
set -e
if [[ $compile_status -ne 0 ]]; then
  cat "$BUILD_DIR/compile.err" >&2
  echo "UNKNOWN_STATE chapter=ch.java-oop.business-value-types phase=compile" >&2
  exit 43
fi

set +e
java -cp "$CLASSES_DIR" BusinessValueChallenge >"$BUILD_DIR/challenge.out" 2>"$BUILD_DIR/challenge.err"
challenge_status=$?
java -cp "$CLASSES_DIR" LooseRegexFailure >"$BUILD_DIR/regex.out" 2>"$BUILD_DIR/regex.err"
regex_status=$?
set -e

if [[ $regex_status -ne 7 ]] || ! grep -Fqx "LOOSE_REGEX_ACCEPTED input=WO- expected=false actual=true" "$BUILD_DIR/regex.err"; then
  cat "$BUILD_DIR/regex.out" "$BUILD_DIR/regex.err" >&2
  echo "UNKNOWN_STATE chapter=ch.java-oop.business-value-types fixture=LooseRegexFailure" >&2
  exit 43
fi

if [[ $challenge_status -eq 0 ]] \
    && [[ ! -s "$BUILD_DIR/challenge.err" ]] \
    && grep -Fqx "challenge.assertions=15 passed" "$BUILD_DIR/challenge.out"; then
  cat "$BUILD_DIR/challenge.out"
  echo "EXERCISE_GREEN chapter=ch.java-oop.business-value-types assertions=15 fixture=preserved"
  exit 0
fi

if [[ $starter_sources_match -eq 1 ]] \
    && [[ $challenge_status -eq 8 ]] \
    && [[ ! -s "$BUILD_DIR/challenge.out" ]] \
    && grep -Fqx "STARTER_DOUBLE_MONEY expected=0.10 actual=0.1000000000000000055511151231257827021181583404541015625" "$BUILD_DIR/challenge.err"; then
  echo "EXPECTED_RED chapter=ch.java-oop.business-value-types first=STARTER_DOUBLE_MONEY status=8"
  exit 41
fi

cat "$BUILD_DIR/challenge.out" "$BUILD_DIR/challenge.err" >&2
echo "UNKNOWN_STATE chapter=ch.java-oop.business-value-types phase=challenge status=$challenge_status" >&2
exit 43
