#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -euo pipefail

# Local mechanical checks must not install a different pnpm into the user's global tool cache.
export npm_config_manage_package_manager_versions=false

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
compile_status=$?
set -e
if [[ $compile_status -ne 0 ]]; then
  echo "$compile_output" >&2
  echo "UNSAFE_OPTIONAL_ACCESS_EXERCISE" >&2
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
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.ts.foundations oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'UNSAFE_OPTIONAL_ACCESS_EXERCISE' <<<"$contract_output" &&
   grep -Fq -- 'UNSAFE_OPTIONAL_ACCESS_EXERCISE' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.ts.foundations oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.ts.foundations expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
