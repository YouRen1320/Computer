#!/usr/bin/env bash
set +e
set -u
set -o pipefail

CHAPTER_ID="ch.security.identity-password-lifecycle"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
SOURCE_FILE="$ROOT_DIR/src/IdentityLifecycleChallenge.java"
STARTER_SHA256="88cde595b8c717cb69a801a7a1278165cc00ec3b7a63d694476e4da1c125f218"
GREEN_MARKER="EXERCISE PASS jdk=25 mode=offline"
RED_MARKER="UNSAFE_STORAGE_ACCEPTED"
EXPECTED_TODO_COUNT="5"

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    return 1
  fi
}

if [[ ! -f "$SOURCE_FILE" ]]; then
  printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=%s reason=missing-source\n' "$CHAPTER_ID" >&2
  exit 43
fi

source_sha256="$(sha256_file "$SOURCE_FILE")"
hash_status=$?
if [[ "$hash_status" -ne 0 || -z "$source_sha256" ]]; then
  printf 'EXERCISE_INFRA_FAILURE chapter=%s reason=sha256-unavailable\n' "$CHAPTER_ID" >&2
  exit 43
fi

case "$(java -version 2>&1 | head -n 1)" in
  *'version "25.'*|*'version "25"'*) ;;
  *) printf 'EXERCISE_INFRA_FAILURE chapter=%s reason=java-25-required\n' "$CHAPTER_ID" >&2; exit 43 ;;
esac
case "$(javac -version 2>&1)" in
  "javac 25"|"javac 25."*) ;;
  *) printf 'EXERCISE_INFRA_FAILURE chapter=%s reason=javac-25-required\n' "$CHAPTER_ID" >&2; exit 43 ;;
esac

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"
if [[ "$?" -ne 0 ]]; then
  printf 'EXERCISE_INFRA_FAILURE chapter=%s reason=build-directory\n' "$CHAPTER_ID" >&2
  exit 43
fi

javac --release 25 -Xlint:all -Werror -d "$BUILD_DIR/classes" "$SOURCE_FILE" >"$BUILD_DIR/compile.log" 2>&1
compile_status=$?
if [[ "$compile_status" -ne 0 ]]; then
  cat "$BUILD_DIR/compile.log" >&2
  printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=%s reason=compile status=%s\n' "$CHAPTER_ID" "$compile_status" >&2
  exit 43
fi

java -cp "$BUILD_DIR/classes" IdentityLifecycleChallenge >"$BUILD_DIR/runtime.log" 2>&1
runtime_status=$?
cat "$BUILD_DIR/runtime.log"

if [[ "$runtime_status" -eq 0 ]] && grep -Fxq -- "$GREEN_MARKER" "$BUILD_DIR/runtime.log"; then
  printf 'EXERCISE_GREEN chapter=%s oracle=completed-solution\n' "$CHAPTER_ID"
  exit 0
fi

todo_count="$(grep -c 'TODO' "$SOURCE_FILE" || true)"
if [[ "$runtime_status" -ne 0 ]] &&
   [[ "$source_sha256" == "$STARTER_SHA256" ]] &&
   [[ "$todo_count" == "$EXPECTED_TODO_COUNT" ]] &&
   grep -Fq -- "$RED_MARKER" "$BUILD_DIR/runtime.log"; then
  printf 'EXPECTED_RED chapter=%s first=%s todos=%s jdk=25 mode=offline\n' \
    "$CHAPTER_ID" "$RED_MARKER" "$EXPECTED_TODO_COUNT"
  exit 41
fi

printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=%s runtime_status=%s starter_sha256=%s todo_count=%s\n' \
  "$CHAPTER_ID" "$runtime_status" "$source_sha256" "${todo_count:-0}" >&2
exit 43
