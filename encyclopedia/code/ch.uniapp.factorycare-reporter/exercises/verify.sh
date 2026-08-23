#!/usr/bin/env bash
set +e
set -u
set -o pipefail

CHAPTER_ID="ch.uniapp.factorycare-reporter"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_FILE="$ROOT_DIR/answer.json"
STARTER_SHA256="ac54f07c3f512140e151d3bd191501bbe30d6eced4fd6d86e30c0ee8546a2b7e"

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

contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -euo pipefail
cd "$ROOT_DIR"
node oracle.mjs
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf 'EXERCISE_GREEN chapter=%s oracle=completed-solution\n' "$CHAPTER_ID"
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   [[ "$source_sha256" == "$STARTER_SHA256" ]] &&
   grep -Fq -- 'EXPECTED_UNIAPP_FACTORYCARE_REPORTER_RED' <<<"$contract_output"; then
  printf 'EXPECTED_RED chapter=%s oracle=verified-starter-failure\n' "$CHAPTER_ID"
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=%s expected_status=1 actual_status=%s starter_sha256=%s\n' \
  "$CHAPTER_ID" "$contract_status" "$source_sha256" >&2
exit 43
