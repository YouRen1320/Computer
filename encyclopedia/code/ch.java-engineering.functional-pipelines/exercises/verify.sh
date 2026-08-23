#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
CLASSES_DIR="$BUILD_DIR/classes"
STARTER_SOURCE_SHA256="0c3c4713c33e9ecd2e4215a26f231e312e94d38377b3a95736ddc246cea38e76"

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
  echo "UNKNOWN_STATE chapter=ch.java-engineering.functional-pipelines phase=starter-fingerprint" >&2
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
javac --release 25 -Xlint:all -Werror -d "$CLASSES_DIR" "$ROOT_DIR"/src/*.java "$ROOT_DIR"/failures/*.java >"$BUILD_DIR/compile.out" 2>"$BUILD_DIR/compile.err"
compile_status=$?
set -e
if [[ $compile_status -ne 0 ]]; then
  cat "$BUILD_DIR/compile.err" >&2
  echo "UNKNOWN_STATE chapter=ch.java-engineering.functional-pipelines phase=compile" >&2
  exit 43
fi

set +e
java -cp "$CLASSES_DIR" OptionalGetContractFailure >"$BUILD_DIR/failure.out" 2>"$BUILD_DIR/failure.err"
failure_status=$?
java -cp "$CLASSES_DIR" FunctionalPipelinesChallenge >"$BUILD_DIR/challenge.out" 2>"$BUILD_DIR/challenge.err"
challenge_status=$?
set -e

if [[ $failure_status -eq 0 ]] || ! grep -Fq 'OPTIONAL_EMPTY_GET' "$BUILD_DIR/failure.err"; then
  cat "$BUILD_DIR/failure.out" "$BUILD_DIR/failure.err" >&2
  echo "UNKNOWN_STATE chapter=ch.java-engineering.functional-pipelines fixture=OptionalGetContractFailure" >&2
  exit 43
fi

if [[ $challenge_status -eq 0 ]] \
    && [[ ! -s "$BUILD_DIR/challenge.err" ]] \
    && grep -Fqx 'CHALLENGE PASS assertions=5' "$BUILD_DIR/challenge.out" \
    && [[ $(wc -l <"$BUILD_DIR/challenge.out") -eq 1 ]]; then
  cat "$BUILD_DIR/challenge.out"
  echo "EXERCISE_GREEN chapter=ch.java-engineering.functional-pipelines fixture=preserved"
  exit 0
fi

if [[ $starter_sources_match -eq 1 ]] \
    && [[ $challenge_status -eq 1 ]] \
    && grep -Fq 'PIPELINE_CONTRACT' "$BUILD_DIR/challenge.err"; then
  echo "EXPECTED_RED chapter=ch.java-engineering.functional-pipelines first=PIPELINE_CONTRACT status=1"
  exit 41
fi

cat "$BUILD_DIR/challenge.out" "$BUILD_DIR/challenge.err" >&2
echo "UNKNOWN_STATE chapter=ch.java-engineering.functional-pipelines phase=challenge status=$challenge_status" >&2
exit 43
