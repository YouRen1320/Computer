#!/usr/bin/env bash
set +e
contract_log="$(mktemp "${TMPDIR:-/tmp}/factorycare-exercise-contract.XXXXXX")"
cleanup_contract_log() { rm -f "$contract_log"; }
trap cleanup_contract_log EXIT HUP INT TERM
(
set -euo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
if [[ -n "${PYTHON_BIN:-}" ]]; then
  "$PYTHON_BIN" -m pytest -q -p no:cacheprovider
else
  uv run --no-project --python 3.14 --with 'pytest==9.1.1' --with 'pydantic==2.13.4' -- python -m pytest -q -p no:cacheprovider
fi
) >"$contract_log" 2>&1
contract_status=$?
contract_output="$(cat "$contract_log")"
cleanup_contract_log
trap - EXIT HUP INT TERM
if [[ -n "$contract_output" ]]; then
  printf '%s\n' "$contract_output"
fi
if [[ "$contract_status" -eq 0 ]]; then
  printf '%s\n' 'EXERCISE_GREEN chapter=ch.rag.citations-evaluation oracle=completed-solution'
  exit 0
fi
if [[ "$contract_status" -eq 1 ]] &&
   grep -Fq -- 'test_citation.py::test_citation_is_the_smallest_exact_supporting_span' <<<"$contract_output" &&
   grep -Fq -- '1 failed' <<<"$contract_output"; then
  printf '%s\n' 'EXPECTED_RED chapter=ch.rag.citations-evaluation oracle=verified-starter-failure'
  exit 41
fi
printf 'EXERCISE_FAILURE_SHAPE_MISMATCH chapter=ch.rag.citations-evaluation expected_status=1 actual_status=%s\n' "$contract_status" >&2
exit 43
