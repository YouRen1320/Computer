#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
export UV_NO_PROGRESS=1
cd "$(dirname "$0")"
uv run \
  --python 3.14 \
  --with 'fastapi==0.139.2' \
  --with 'pydantic==2.13.4' \
  --with 'starlette==1.3.1' \
  --with 'httpx==0.28.1' \
  python scripts/check.py
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.fastapi.web-foundations oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'AssertionError: EXPECTED RED: public response leaked or drifted: {'"'"'id'"'"': '"'"'WO-001'"'"', '"'"'title'"'"': '"'"'Inspect pump'"'"', '"'"'priority'"'"': 4, '"'"'internal_secret'"'"': '"'"'leaked'"'"'}' <<<"$contract_output" &&
   grep -Fq -- 'AssertionError' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.fastapi.web-foundations oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.fastapi.web-foundations expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
