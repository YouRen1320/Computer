#!/usr/bin/env bash
set +e
set -u
set -o pipefail

CHAPTER_ID="ch.ts.modeling-narrowing"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_FILE="$ROOT_DIR/src/exercise.ts"
STARTER_SHA256="5d370350beb6e57540bbcad1d67e3c986e1c0672d1491d9dffd20dff89d57bef"

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

# Local mechanical checks must not install a different pnpm into the user's global tool cache.
export npm_config_manage_package_manager_versions=false

TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR" "$ROOT_DIR/node_modules" "$ROOT_DIR/.verify-dist"
}
trap cleanup EXIT

cd "$ROOT_DIR"
pnpm install --offline --frozen-lockfile --ignore-scripts >/dev/null
[[ "$(pnpm exec tsc --version)" == "Version 7.0.2" ]]

set +e
compile_output="$(pnpm exec tsc --project tsconfig.json --noEmit --pretty false 2>&1)"
compile_rc=$?
set -e
if [[ $compile_rc -ne 0 ]]; then
  echo "$compile_output" >&2
  echo "MODELING_NARROWING_EXERCISE_RED" >&2
  exit 1
fi

pnpm exec tsc --project tsconfig.emit.json --pretty false
node .verify-dist/exercise.js >"$TMP_DIR/actual.stdout"
diff -u expected.stdout "$TMP_DIR/actual.stdout"
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
   grep -Fq -- 'MODELING_NARROWING_EXERCISE_RED' <<<"$contract_output"; then
  printf 'EXPECTED_RED chapter=%s oracle=verified-starter-failure\n' "$CHAPTER_ID"
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=%s expected_status=1 actual_status=%s starter_sha256=%s\n' \
  "$CHAPTER_ID" "$contract_status" "$source_sha256" >&2
exit 43
