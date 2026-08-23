#!/usr/bin/env bash
set +e
set -u
set -o pipefail

CHAPTER_ID="ch.css.theme-variables"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
STARTER_SHA256="3c90e72ef5ecb0a66db599b7a95b10f9b4a5cf3c7e80799376f5adcb99e643d9"
STARTER_FILES=("index.html" "styles.css" "theme-matrix.json")
GREEN_MARKER="CSS_THEME_EXERCISE=PASS"

cd "$ROOT_DIR" || {
  printf 'EXERCISE_INFRA_FAILURE chapter=%s reason=cannot-enter-root\n' "$CHAPTER_ID" >&2
  exit 43
}

sha256_stream() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    return 1
  fi
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    return 1
  fi
}

for path in "${STARTER_FILES[@]}"; do
  if [[ ! -f "$path" ]]; then
    printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=%s reason=missing-input path=%s\n' "$CHAPTER_ID" "$path" >&2
    exit 43
  fi
done

starter_sha256="$(
  for path in "${STARTER_FILES[@]}"; do
    digest="$(sha256_file "$path")" || exit 1
    printf '%s\0%s\0' "$path" "$digest"
  done | sha256_stream
)"
hash_status=$?
if [[ "$hash_status" -ne 0 || -z "$starter_sha256" ]]; then
  printf 'EXERCISE_INFRA_FAILURE chapter=%s reason=sha256-unavailable\n' "$CHAPTER_ID" >&2
  exit 43
fi

output="$(ruby oracle.rb 2>&1)"
status=$?
if [[ -n "$output" ]]; then
  printf '%s\n' "$output"
fi

if [[ "$status" -eq 0 ]] && grep -Fxq -- "$GREEN_MARKER" <<<"$output"; then
  printf 'EXERCISE_GREEN chapter=%s oracle=completed-solution\n' "$CHAPTER_ID"
  exit 0
fi

if [[ "$status" -eq 1 ]] &&
   [[ "$starter_sha256" == "$STARTER_SHA256" ]] &&
   diff -u expected-red.out <(printf '%s\n' "$output") >/dev/null; then
  printf 'EXPECTED_RED chapter=%s oracle=verified-starter-failure\n' "$CHAPTER_ID"
  exit 41
fi

printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=%s expected_red_status=1 actual_status=%s starter_sha256=%s\n' \
  "$CHAPTER_ID" "$status" "$starter_sha256" >&2
exit 43
